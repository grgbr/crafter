################################################################################
# Kbuild based module helpers.
#
# Implement the necessary logic used to ease the writing of Kbuild based module
# rules. Allows to focus mainly on writing build logic instead of struggling
# with makefile constructs.
# Include this file at the top of your module implementation Makefile.
#
# Basically this file provides:
# * a set of commands wrapping native Kbuild Makefile targets invocation in a
#   way that is suitable to Crafter rules structure ;
# * a set of macros allowing to generate rules required for invoking native
#   Kbuild targets from within a Crafter module.
#
# For each Crafter standard target you will find a correponding macro that will
# generate required rules. These macros must be given, as parameter, the name of
# a variable holding the target specific recipe (block of commands). Theses
# macros are named according to the following scheme:
#   kbuild_gen_<crafter_target>_rule[s]
#
# On a per-target basis, module writer may arbitrarily choose to use these
# macros from within module Makefile, or to write his own Makefile constructs to
# address a specific target requirement.
################################################################################

# kbuild_configured - Check wether current Kbuild module has been configured or
#                     not.
#
# Expand to «y» if configured, «n» otherwise
kbuild_configured = $(if $(realpath $(module_builddir)/.config),y,n)

################################################################################
# Kbuild commands
################################################################################

# kbuild_make_cmd() - Expand to a shell command allowing to run a Kbuild make
#                     operation.
#
# $(1): Kbuild compliant source tree
# $(2): Kbuild make targets
# $(3): Kbuild make arguments
define kbuild_make_cmd
$(MAKE) -C $(1) $(2) $(verbosity) O:=$(module_builddir) $(3)
endef

# kbuild_config_cmd() - Expand to a shell command allowing to run a Kbuild make
#                       config operation.
#
# $(1): Kbuild compliant source tree
# $(2): Kbuild make config target
# $(3): Kbuild make arguments
#
# Usual config targets are: config, oldconfig, defconfig, etc...
define kbuild_config_cmd
$(call log_action,KCONF,$(module_builddir)/.config); \
$(MAKE) $(if $(Q),--quiet) \
        -C $(1) \
        $(2) $(verbosity) O:=$(module_builddir) $(3) \
        $(redirect)
endef

# kbuild_merge_config_cmd() - Expand to a shell command allowing to merge
#                             multiple Kbuild / Kconfig configuration files.
#
# $(1): Kbuild compliant source tree
# $(2): list of paths to config files to merge
# $(3): Kbuild make arguments
define kbuild_merge_config_cmd
$(call log_action,KMERGE,$(module_builddir)/.config); \
$(if $(Q),$(foreach f,$(2),$(call log_action,,$(f));)) \
cd $(module_builddir) && \
$(CRAFTER_SCRIPTDIR)/kconfig_merge.sh -m .config $(2) $(redirect) && \
$(MAKE) $(if $(Q),--quiet) -C $(1) olddefconfig \
        $(verbosity) O:=$(module_builddir) $(3)
endef

# kbuild_saveconfig_cmd() - Expand to a shell command allowing to save current
#                           Kbuild / Kconfig configuration.
#
# $(1): Kbuild compliant source tree
# $(2): Kbuild make arguments
define kbuild_saveconfig_cmd
$(call log_action,KSAVE,$(module_builddir)/defconfig); \
$(MAKE) $(if $(Q),--quiet) \
        -C $(1) \
        savedefconfig \
        $(verbosity) O:=$(module_builddir) $(2)
endef

# kbuild_guiconfig_cmd() - Expand to a shell command allowing to lauch a Kconfig
#                          GUI configurator.
#
# $(1): Kbuild compliant source tree
# $(3): Kbuild make arguments
#
# The choice of the configurator may customized by setting up the
# CRAFTER_KBUILD_GUICONFIG variable either on the command line or by parsing
# the user's $(CONFIGDIR)/crafter.mk main crafter customization makefile.
#
# If CRAFTER_KBUILD_GUICONFIG is unset, configurator will default to xconfig.
#
# Usual configurators are: xconfig, menuconfig, etc...
define kbuild_guiconfig_cmd
$(call log_action,KGUI,$(module_builddir)/.config); \
$(MAKE) $(if $(Q),--quiet) \
        -C $(1) \
        $(if $(CRAFTER_KBUILD_GUICONFIG),$(CRAFTER_KBUILD_GUICONFIG),xconfig) \
        $(verbosity) O:=$(module_builddir) $(2)
endef

################################################################################
# Kbuild rules handling
################################################################################

define _kbuild_config_rules
.PHONY: defconfig
defconfig: $(module_prereqs) \
           | $(call stampdir,$(MODULENAME)) $(module_builddir)
	$$($(strip $(2)))
	$$(if $$(realpath $(1)),$$($(strip $(3))))
	$(Q)touch $(config_target)

.PHONY: $(module_builddir)/defconfig
$(module_builddir)/defconfig: $(config_target)
	$$($(strip $(4)))

.PHONY: saveconfig
saveconfig: $(module_builddir)/defconfig

.PHONY: guiconfig
guiconfig: $(module_builddir)/.config
	$$($(strip $(5)))
	$(Q)touch $(config_target)

$(config_target): $(module_builddir)/.config $(CRAFTERDIR)/core/kbuild.mk

$(module_builddir)/.config: $$(realpath $(1)) \
                            $(module_prereqs) \
                            | $(call stampdir,$(MODULENAME)) \
                              $(module_builddir)
	$$(if $$(realpath $$(@)),,$$($(strip $(2))))
	$$(if $$(realpath $(1)),$$($(strip $(3))))
endef

# kbuild_gen_config_rules() - Generate rules required for calling Kbuild
#                             configuration targets.
#
# $(1): optional additional Kbuild configuration file paths.
# $(2): name of defconfig recipe variable
# $(3): name of optional merge config recipe variable
# $(4): name of saveconfig recipe variable
# $(5): name of guiconfig recipe variable
#
# First parameter should hold the list of additional Kbuild configuration files
# to be merged with default one.
define kbuild_gen_config_rules
$(eval $(call _kbuild_config_rules,$(1),$(2),$(3),$(4),$(5)))
endef

define _kbuild_build_rule
$(build_target):
	$$($(strip $(1)))
	$(Q)touch $$(@)
endef

# kbuild_gen_build_rule() - Generate rule required for calling Kbuild build
#                           target.
#
# $(1): name of build recipe variable
define kbuild_gen_build_rule
$(eval $(call _kbuild_build_rule,$(1)))
endef

define _kbuild_clean_rule
clean:
	$$($(strip $(1)))
endef

# kbuild_gen_clean_rule() - Generate rule required for calling Kbuild clean
#                           target.
#
# $(1): name of clean recipe variable
define kbuild_gen_clean_rule
$(eval $(call _kbuild_clean_rule,$(1)))
endef

define _kbuild_install_rule
$(install_target):
	$$($(strip $(1)))
	$(Q)touch $$(@)
endef

# kbuild_gen_install_rule() - Generate rule required for calling Kbuild install
#                             target.
#
# $(1): name of install recipe variable
define kbuild_gen_install_rule
$(eval $(call _kbuild_install_rule,$(1)))
endef

define _kbuild_uninstall_rule
uninstall:
	$$($(strip $(1)))
endef

# kbuild_gen_uninstall_rule() - Generate rule required for calling Kbuild
#                               uninstall target.
#
# $(1): name of uninstall recipe variable
define kbuild_gen_uninstall_rule
$(eval $(call _kbuild_uninstall_rule,$(1)))
endef

define _kbuild_bundle_rule
$(bundle_target):
	$$($(strip $(1)))
	$(Q)touch $$(@)
endef

# kbuild_gen_bundle_rule() - Generate rule required for calling Kbuild bundle
#                            target.
#
# $(1): name of bundle recipe variable
define kbuild_gen_bundle_rule
$(eval $(call _kbuild_bundle_rule,$(1)))
endef

define _kbuild_drop_rule
drop:
	$$($(strip $(1)))
endef

# kbuild_gen_drop_rule() - Generate rule required for calling Kbuild drop
#                          target.
#
# $(1): name of drop recipe variable
define kbuild_gen_drop_rule
$(eval $(call _kbuild_drop_rule,$(1)))
endef

define _kbuild_native_rules
.PHONY: help
help: | $(module_builddir)

.PHONY: cscope tags
cscope tags: $(config_target)

help cscope tags:
	$$(call $(strip $(1)),$$(@))
endef

# kbuild_gen_native_rules() - Generate rules required for relaying targets
#                             invocation to module's native Kbuild Makefile
#                             as-is.
#
# $(1): name of native recipe macro
#
# The idea here is to allow invocation of module's Kbuild targets which are not
# part of crafter's standard target scheme.
# Supported usual Kbuild targets are:
# * help   -- to run module's native help target
# * cscope -- to run module's native cscope target
# * tags   -- to run module's native tags target
#
# These targets may be called from command line according to the following
# scheme:
#   <module_name>-<native_target>
#
# $(1) parameter must be the name of a macro holding the recipe used to relay
# target invocation to module's native Kbuild Makefile.
# At expanding time, this macro is given a single parameter holding the name of
# the invoked target, i.e. one of the targets listed above.
define kbuild_gen_native_rules
$(eval $(call _kbuild_native_rules,$(1)))
endef
