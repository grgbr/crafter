################################################################################
# Meson based module helpers.
#
# Implement the necessary logic used to ease the writing of Meson based
# module rules. Allows to focus mainly on writing build logic instead of
# struggling with makefile constructs.  Include this file at the top of your
# module implementation Makefile.
#
# Basically this file provides:
# * a set of commands wrapping native Meson generated Makefile targets
#   invocation in a way that is suitable to Crafter rules structure ;
# * a set of macros allowing to generate rules required for invoking native
#   Meson targets from within a Crafter module.
#
# For each Crafter standard target you will find a correponding macro that will
# generate required rules. These macros must be given, as parameter, the name of
# a variable holding the target specific recipe (block of commands). Theses
# macros are named according to the following scheme:
#   meson_gen_<crafter_target>_rule[s]
#
# On a per-target basis, module writer may arbitrarily choose to use these
# macros from within module Makefile, or to write his own Makefile constructs to
# address a specific target requirement.
#
# See also https://mesonbuild.com
################################################################################

MESON ?= meson

################################################################################
# Meson related commands.
#
# Use theses from within module recipes to implement Meson based module
# build.
#
# For infos about cross building, see also:
# https://mesonbuild.com/Cross-compilation.html
################################################################################

# meson_target_configure() - Expand to a shell construct suitable for running
#                            the Meson based current module target configure
#                            operation.
# $(1): path to source directory
# $(2): environment to run meson with
# $(3): arguments to invoke meson with
#
# Configure the build of current module for out-of-tree build and according to
# arguments given as $(2) parameter.
#
# '--wrap-mode=nodownload' option ensures that meson will not download
# subproject sources behind our back. See:
#     https://mesonbuild.com/Wrap-dependency-system-manual.html
#     https://mesonbuild.com/FAQ.html#does-wrap-download-sources-behind-my-back
define meson_target_setup
$(call log_action,MECONF,$(module_builddir)); \
if $(MESON) introspect --projectinfo $(module_builddir) >/dev/null 2>&1; then \
	env $(2) $(MESON) setup \
	                  --reconfigure \
	                  --wrap-mode=nodownload \
	                  --cross-file="$(module_builddir)/meson.ini" \
	                  $(3) \
	                  $(module_builddir) \
	                  $(1); \
else \
	env $(2) $(MESON) setup \
	                  --wrap-mode=nodownload \
	                  --cross-file="$(module_builddir)/meson.ini" \
	                  $(3) \
	                  $(module_builddir) \
	                  $(1); \
fi
endef

# meson_target_run() - Expand to a shell command allowing to run a Meson target
#                      for current module.
# $(1): meson target
# $(2): environment to run meson with
# $(3): arguments to invoke meson with
define meson_target_run
env $(2) $(MESON) $(1) -C $(module_builddir) $(3)
endef

################################################################################
# Meson rules handling
################################################################################

define _meson_ini
$(1)

# Meson build system host file for cross compiling using XtChain.
#
# See https://mesonbuild.com/Machine-files.html for general informations about
# machine files
#
# Meson documentation describes \'host_machine\' section properties here:
#     https://mesonbuild.com/Reference-tables.html#
#
[host_machine]
system = \'linux\'
cpu_family = \'$(strip $(2))\'
cpu = \'$(strip $(3))\'
endian = \'$(strip $(4))\'
endef

define _meson_ini_rules
$(module_builddir)/meson.ini: SHELL:=/bin/bash
$(module_builddir)/meson.ini: $(module_prereqs) \
                              $(CRAFTERDIR)/core/meson.mk \
                              | $(call stampdir,$(MODULENAME)) \
                                $(module_builddir)
	$(Q)$$(call echo_multi_line_var_cmd,$$(call _meson_ini,$$($(strip $(1))), \
	                                                       $$($(strip $(2))), \
	                                                       $$($(strip $(3))), \
	                                                       $$($(strip $(4))))) > $$(@)
endef

# meson_gen_ini_rules() - Generate rules required initializing Meson ini
#                         configuration file.
#
# $(1): Meson toolchain ini file content
# $(2): Meson target host cpu_family
# $(3): Meson target host cpu
# $(4): Meson target host endian
define meson_gen_ini_rules
$(eval $(call _meson_ini_rules,$(1),$(2),$(3),$(4)))
endef

define _meson_config_rules
$(config_target): $(module_builddir)/meson.ini
	$$($(strip $(1)))
	$(Q)touch $$(@)
endef

# meson_gen_config_rules() - Generate rules required for calling Meson based
#                            configuration target.
#
# $(1): name of meson configure recipe variable
define meson_gen_config_rules
$(eval $(call _meson_config_rules,$(1)))
endef

define _meson_build_rule
$(build_target):
	$$($(strip $(1)))
	$(Q)touch $$(@)
endef

# meson_gen_build_rule() - Generate rules required for calling Meson based
#                          build target.
#
# $(1): name of meson build recipe variable
define meson_gen_build_rule
$(eval $(call _meson_build_rule,$(1)))
endef

define _meson_clean_rule
clean:
	$(if $(realpath $(config_target)),-$$($(strip $(1))))
endef

# meson_gen_clean_rule() - Generate rules required for calling Meson based clean
#                          target.
#
# $(1): name of meson clean recipe variable
define meson_gen_clean_rule
$(eval $(call _meson_clean_rule,$(1)))
endef

define _meson_install_rule
$(install_target):
	$$($(strip $(1)))
	$(Q)touch $$(@)
endef

# meson_gen_install_rule() - Generate rules required for calling Meson based
#                            install target.
#
# $(1): name of meson install recipe variable
define meson_gen_install_rule
$(eval $(call _meson_install_rule,$(1)))
endef

define _meson_uninstall_rule
uninstall:
	$(if $(realpath $(config_target)),-$$($(strip $(1))))
endef

# meson_gen_uninstall_rule() - Generate rules required for calling Meson based
#                              uninstall target.
#
# $(1): name of meson uninstall recipe variable
define meson_gen_uninstall_rule
$(eval $(call _meson_uninstall_rule,$(1)))
endef

define _meson_bundle_rule
$(bundle_target):
	$$($(strip $(1)))
	$(Q)touch $$(@)
endef

# meson_gen_bundle_rule() - Generate rules required for calling Meson based
#                           bundle target.
#
# $(1): name of meson bundle recipe variable
define meson_gen_bundle_rule
$(eval $(call _meson_bundle_rule,$(1)))
endef

define _meson_drop_rule
drop:
	$(if $(realpath $(config_target)),$$($(strip $(1))))
endef

# meson_gen_drop_rule() - Generate rules required for calling Meson based drop
#                         target.
#
# $(1): name of meson drop recipe variable
define meson_gen_drop_rule
$(eval $(call _meson_drop_rule,$(1)))
endef
