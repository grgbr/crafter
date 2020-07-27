################################################################################
# Ebuild based module helpers.
#
# Implement the necessary logic used to ease the writing of Ebuild based module
# rules. Allows to focus mainly on writing build logic instead of struggling
# with makefile constructs.
# Include this file at the top of your module implementation Makefile.
#
# Basically this file provides:
# * a set of commands wrapping native Ebuild Makefile targets invocation in a
#   way that is suitable to Crafter rules structure ;
# * a set of macros allowing to generate rules required for invoking native
#   Ebuild targets from within a Crafter module.
#
# For each Crafter standard target you will find a correponding macro that will
# generate required rules. These macros must be given, as parameter, the name of
# a variable holding the target specific recipe (block of commands). Theses
# macros are named according to the following scheme:
#   ebuild_gen_<crafter_target>_rule[s]
#
# On a per-target basis, module writer may arbitrarily choose to use these
# macros from within module Makefile, or to write his own Makefile constructs to
# address a specific target requirement.
################################################################################

# ebuild_configured - Check wether current Ebuild module has been configured or
#                     not.
#
# Expand to «y» if configured, «n» otherwise
ebuild_configured = $(if $(realpath $(module_builddir)/.config),y,n)

################################################################################
# Ebuild commands
################################################################################

# ebuild_make_cmd() - Expand to a shell command allowing to run a Ebuild make
#                     operation.
#
# $(1): Ebuild compliant source tree
# $(2): Ebuild make targets
# $(3): Ebuild make arguments
define ebuild_make_cmd
$(MAKE) -C $(1) $(2) $(verbosity) BUILDDIR:=$(module_builddir) $(3)
endef

# ebuild_config_cmd() - Expand to a shell command allowing to run a Ebuild make
#                       config operation.
#
# $(1): Ebuild compliant source tree
# $(2): Ebuild make config target
# $(3): Ebuild make arguments
#
# Usual config targets are: config, oldconfig, defconfig, etc...
define ebuild_config_cmd
$(call log_action,KCONF,$(module_builddir)/.config); \
$(MAKE) $(if $(Q),--quiet) \
        -C $(1) \
        $(2) $(verbosity) O:=$(module_builddir) $(3) \
        $(redirect)
endef

# ebuild_merge_config_cmd() - Expand to a shell command allowing to merge
#                             multiple Ebuild / Kconfig configuration files.
#
# $(1): Ebuild compliant source tree
# $(2): list of paths to config files to merge
# $(3): Ebuild make arguments
define ebuild_merge_config_cmd
$(call log_action,KMERGE,$(module_builddir)/.config); \
$(if $(Q),$(foreach f,$(2),$(call log_action,,$(f));)) \
cd $(module_builddir) && \
$(CRAFTER_SCRIPTDIR)/kconfig_merge.sh -m .config $(2) $(redirect) && \
$(MAKE) $(if $(Q),--quiet) -C $(1) olddefconfig \
        $(verbosity) O:=$(module_builddir) $(3)
endef

# ebuild_saveconfig_cmd() - Expand to a shell command allowing to save current
#                           Ebuild / Kconfig configuration.
#
# $(1): Ebuild compliant source tree
# $(2): Ebuild make arguments
define ebuild_saveconfig_cmd
$(call log_action,KSAVE,$(module_builddir)/defconfig); \
$(MAKE) $(if $(Q),--quiet) \
        -C $(1) \
        savedefconfig \
        $(verbosity) O:=$(module_builddir) $(2)
endef

# ebuild_guiconfig_cmd() - Expand to a shell command allowing to lauch a Kconfig
#                          GUI configurator.
#
# $(1): Ebuild compliant source tree
# $(3): Ebuild make arguments
#
# The choice of the configurator may customized by setting up the
# CRAFTER_EBUILD_GUICONFIG variable either on the command line or by parsing
# the user's $(CONFIGDIR)/crafter.mk main crafter customization makefile.
#
# If CRAFTER_EBUILD_GUICONFIG is unset, configurator will default to xconfig.
#
# Usual configurators are: xconfig, menuconfig, etc...
define ebuild_guiconfig_cmd
$(call log_action,KGUI,$(module_builddir)/.config); \
$(MAKE) $(if $(Q),--quiet) \
        -C $(1) \
        $(if $(CRAFTER_EBUILD_GUICONFIG),$(CRAFTER_EBUILD_GUICONFIG),xconfig) \
        $(verbosity) O:=$(module_builddir) $(2)
endef

################################################################################
# Ebuild rules handling
################################################################################

define _ebuild_config_rules
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

$(config_target): $(module_builddir)/.config $(CRAFTERDIR)/core/ebuild.mk

$(module_builddir)/.config: $$(realpath $(1)) \
                            $(module_prereqs) \
                            | $(call stampdir,$(MODULENAME)) \
                              $(module_builddir)
	$$(if $$(realpath $$(@)),,$$($(strip $(2))))
	$$(if $$(realpath $(1)),$$($(strip $(3))))
endef

# ebuild_gen_config_rules() - Generate rules required for calling Ebuild
#                             configuration targets.
#
# $(1): optional additional Ebuild configuration file paths.
# $(2): name of defconfig recipe variable
# $(3): name of optional merge config recipe variable
# $(4): name of saveconfig recipe variable
# $(5): name of guiconfig recipe variable
#
# First parameter should hold the list of additional Ebuild configuration files
# to be merged with default one.
define ebuild_gen_config_rules
$(eval $(call _ebuild_config_rules,$(1),$(2),$(3),$(4),$(5)))
endef

define _ebuild_build_rule
$(build_target):
	$$($(strip $(1)))
	$(Q)touch $$(@)
endef

# ebuild_gen_build_rule() - Generate rule required for calling Ebuild build
#                           target.
#
# $(1): name of build recipe variable
define ebuild_gen_build_rule
$(eval $(call _ebuild_build_rule,$(1)))
endef

define _ebuild_clean_rule
clean:
	$$($(strip $(1)))
endef

# ebuild_gen_clean_rule() - Generate rule required for calling Ebuild clean
#                           target.
#
# $(1): name of clean recipe variable
define ebuild_gen_clean_rule
$(eval $(call _ebuild_clean_rule,$(1)))
endef

define _ebuild_install_rule
$(install_target):
	$$($(strip $(1)))
	$(Q)touch $$(@)
endef

# ebuild_gen_install_rule() - Generate rule required for calling Ebuild install
#                             target.
#
# $(1): name of install recipe variable
define ebuild_gen_install_rule
$(eval $(call _ebuild_install_rule,$(1)))
endef

define _ebuild_uninstall_rule
uninstall:
	$$($(strip $(1)))
endef

# ebuild_gen_uninstall_rule() - Generate rule required for calling Ebuild
#                               uninstall target.
#
# $(1): name of uninstall recipe variable
define ebuild_gen_uninstall_rule
$(eval $(call _ebuild_uninstall_rule,$(1)))
endef

define _ebuild_bundle_rule
$(bundle_target):
	$$($(strip $(1)))
	$(Q)touch $$(@)
endef

# ebuild_gen_bundle_rule() - Generate rule required for calling Ebuild bundle
#                            target.
#
# $(1): name of bundle recipe variable
define ebuild_gen_bundle_rule
$(eval $(call _ebuild_bundle_rule,$(1)))
endef

define _ebuild_drop_rule
drop:
	$$($(strip $(1)))
endef

# ebuild_gen_drop_rule() - Generate rule required for calling Ebuild drop
#                          target.
#
# $(1): name of drop recipe variable
define ebuild_gen_drop_rule
$(eval $(call _ebuild_drop_rule,$(1)))
endef

define _ebuild_native_rules
.PHONY: help
help: | $(module_builddir)

.PHONY: cscope tags
cscope tags: $(config_target)

help cscope tags:
	$$(call $(strip $(1)),$$(@))
endef

# ebuild_gen_native_rules() - Generate rules required for relaying targets
#                             invocation to module's native Ebuild Makefile
#                             as-is.
#
# $(1): name of native recipe macro
#
# The idea here is to allow invocation of module's Ebuild targets which are not
# part of crafter's standard target scheme.
# Supported usual Ebuild targets are:
# * help   -- to run module's native help target
# * cscope -- to run module's native cscope target
# * tags   -- to run module's native tags target
#
# These targets may be called from command line according to the following
# scheme:
#   <module_name>-<native_target>
#
# $(1) parameter must be the name of a macro holding the recipe used to relay
# target invocation to module's native Ebuild Makefile.
# At expanding time, this macro is given a single parameter holding the name of
# the invoked target, i.e. one of the targets listed above.
define ebuild_gen_native_rules
$(eval $(call _ebuild_native_rules,$(1)))
endef
