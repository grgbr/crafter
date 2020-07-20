################################################################################
# CMake based module helpers.
#
# Implement the necessary logic used to ease the writing of CMake based
# module rules. Allows to focus mainly on writing build logic instead of
# struggling with makefile constructs.  Include this file at the top of your
# module implementation Makefile.
#
# Basically this file provides:
# * a set of commands wrapping native CMake generated Makefile targets
#   invocation in a way that is suitable to Crafter rules structure ;
# * a set of macros allowing to generate rules required for invoking native
#   CMake targets from within a Crafter module.
#
# For each Crafter standard target you will find a correponding macro that will
# generate required rules. These macros must be given, as parameter, the name of
# a variable holding the target specific recipe (block of commands). Theses
# macros are named according to the following scheme:
#   cmake_gen_<crafter_target>_rule[s]
#
# On a per-target basis, module writer may arbitrarily choose to use these
# macros from within module Makefile, or to write his own Makefile constructs to
# address a specific target requirement.
################################################################################

################################################################################
# CMake related commands.
#
# Use theses from within module recipes to implement CMake based module
# build.
################################################################################

# cmake_target_configure() - Expand to a shell construct suitable for running
#                            the CMake based current module configure operation.
# $(1): path to source directory
# $(2): Arguments to invoke cmake with
#
# Configure the build of current module for out-of-tree build and according to
# arguments given as $(2) parameter.
define cmake_target_configure
$(call log_action,CMAKE,$(module_builddir)) && \
cd $(module_builddir) && \
cmake $(if $(Q),--no-warn-unused-cli) $(2) $(1) $(redirect)
endef

# cmake_target_make() - Expand to a shell command allowing to run a CMake based
#                       make operation for current module.

# $(1): cmake make targets
# $(2): cmake arguments to invoke make with
define cmake_target_make
$(MAKE) -C $(module_builddir) $(1) $(2) $(if $(Q),,VERBOSE:=1)
endef

################################################################################
# CMake configure rules handling
################################################################################

define _cmake_config_rule
$(config_target): $(CRAFTERDIR)/core/cmake.mk
	$$($(strip $(1)))
	$(Q)touch $$(@)
endef

# cmake_gen_config_rules() - Generate rules required for calling CMake based
#                            configuration target.
#
# $(1): name of cmake configure recipe variable
define cmake_gen_config_rule
$(eval $(call _cmake_config_rule,$(1),$(2)))
endef

################################################################################
# CMake build rules handling
################################################################################

define _cmake_build_rule
$(build_target):
	$$($(strip $(1)))
	$(Q)touch $$(@)
endef

# cmake_gen_build_rule() - Generate rules required for calling CMake
#                          based build target.
#
# $(1): name of cmake build recipe variable
define cmake_gen_build_rule
$(eval $(call _cmake_build_rule,$(1)))
endef

################################################################################
# CMake clean rules handling
################################################################################

define _cmake_clean_rule
clean:
	$(if $(realpath $(config_target)),$$($(strip $(1))))
endef

# cmake_gen_clean_rule() - Generate rules required for calling CMake
#                          based clean target.
#
# $(1): name of cmake clean recipe variable
define cmake_gen_clean_rule
$(eval $(call _cmake_clean_rule,$(1)))
endef

################################################################################
# CMake install rules handling
################################################################################

define _cmake_install_rule
$(install_target):
	$$($(strip $(1)))
	$(Q)touch $$(@)
endef

# cmake_gen_install_rule() - Generate rules required for calling CMake
#                            based install target.
#
# $(1): name of cmake install recipe variable
define cmake_gen_install_rule
$(eval $(call _cmake_install_rule,$(1)))
endef

################################################################################
# CMake uninstall rules handling
################################################################################

define _cmake_uninstall_rule
uninstall:
	$(if $(realpath $(config_target)),$$($(strip $(1))))
endef

# cmake_gen_uninstall_rule() - Generate rules required for calling CMake
#                              based uninstall target.
#
# $(1): name of cmake uninstall recipe variable
define cmake_gen_uninstall_rule
$(eval $(call _cmake_uninstall_rule,$(1)))
endef

################################################################################
# CMake bundle rules handling
################################################################################

define _cmake_bundle_rule
$(bundle_target):
	$$($(strip $(1)))
	$(Q)touch $$(@)
endef

# cmake_gen_bundle_rule() - Generate rules required for calling CMake based
#                           bundle target.
#
# $(1): name of cmake bundle recipe variable
define cmake_gen_bundle_rule
$(eval $(call _cmake_bundle_rule,$(1)))
endef

################################################################################
# CMake drop rules handling
################################################################################

define _cmake_drop_rule
drop:
	$(if $(realpath $(config_target)),$$($(strip $(1))))
endef

# cmake_gen_drop_rule() - Generate rules required for calling CMake based drop
#                         target.
#
# $(1): name of cmake drop recipe variable
define cmake_gen_drop_rule
$(eval $(call _cmake_drop_rule,$(1)))
endef
