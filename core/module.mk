################################################################################
# Core module build logic.
#
# Implement the necessary glue around module specific rules to ease module
# implementation. Allows to focus mainly on writing build logic instead of
# struggling with makefile constructs.
#
# Include this file at the top of your module implementation makefile.
# All platform definitions will be available from with this makefile (and the
# every makefile including it). In addition, have a look at
# _platform_module_make_args() macro to understand which top-level variables
# are passed on the command line at make invocation time.
# Finally, macros and variables defined into helpers.mk file (found under to
# crafter core directory) will be available too.
#
# Invoked from main crafter makefile bootstrap.mk in a separate make instance to
# prevent from macros and variables namespace conflicts.
################################################################################

.SUFFIXES:

# all: - The default target
#
# Points to the module's bundle «terminal» target. Keep this first !
.PHONY: all
all: bundle

# ...and utility macros.
include $(CRAFTERDIR)/core/helpers.mk

# Import platform specific definitions...
include $(PLATFORMDIR)/$(TARGET_BOARD)/$(TARGET_FLAVOUR).mk

# module_prereqs - The list of prerequisites the current module depends on.
#
# This list is updated if current module declares dependencies (see
# gen_module_depends() macro).
#
# Basically, every core module, core helpers, current platform
# and current module implementation makefiles are listed here. By default, the
# config target will depend on this.
module_prereqs := $(MODULEDIR)/$(MODULENAME).mk \
                  $(CRAFTERDIR)/core/module.mk \
                  $(CRAFTERDIR)/core/helpers.mk \
                  $(PLATFORMDIR)/$(TARGET_BOARD)/$(TARGET_FLAVOUR).mk

# stamp() - Given the specified target, expand to timestamp file path for
#           current platform
#
# $(1): target
#
# This stamp file is the basic mechanism allowing to implement proper
# inter-module build ordering. Basically, a target will be (re)made if its
# correspondind stamp file is out of date, i.e. does not exist or is older than
# one of its prerequisites.
#
# See targets invocation for more on this...
define stamp
$(call stampdir,$(MODULENAME))/$(1)
endef

module_builddir := $(call builddir,$(MODULENAME))

module_installdir := $(call installdir,$(MODULENAME))

# _list_module_prereqs() - Expand to a set of prerequisites given a list of
#                          dependency modules
#
# $(1): list of dependency modules
define _list_module_prereqs
$(foreach m,$(1),$(call stampdir,$(m))/bundle)
endef

# _module_depends_rule() - Expand to a set of rules defining inter-module
#                          dependency for the current module.
#
# $(1): list of modules the current module depend on
#
# Update the list of prerequisites the current module depends on and make the
# config target depend on them.
#
# Also define the _module_depends internal variable intended for crafter
# top-level inspection usage (see list_module_depends() macro).
#
# This macro is cyclic dependency safe.
define _module_depends_rule
_module_depends := $(filter-out $(MODULENAME),$(1))

module_prereqs += $$(call _list_module_prereqs,$$(_module_depends))

$(config_target): $$(call _list_module_prereqs,$$(_module_depends))
endef

# gen_module_depends() - Generate rules implementing inter-module dependency
#                        for the current module.
#
# $(1): list of modules the current module depend on
#
# You may safely pass $(MODULES) variable as argument since this macro is cyclic
# dependency safe.
# This is an easy way to tell crafter the current module depends on every
# modules the current platform uses.
define gen_module_depends
$(eval $(call _module_depends_rule,$(1)))
endef

# _log_module_target() - Display a message indicating which target is running.
#
# $(1): target name
define _log_module_target
$(call log_target,$(MODULENAME),$(1))
endef

################################################################################
# config: - Current module config target
#
# Configure build of current module for current platform.
#
# The config target recipe is optional. If empty, the corresponding stamp file
# will be created to ensure proper dependency chaining.
#
# Also note that all other crafter module rules generating objects will depend
# on the config target, allowing straightforward basic intra-module dependency
# handling implementation.
################################################################################

config_target := $(call stamp,config)

.PHONY: config
config: $(config_target)

# Make the config target depend on the computed set of prerequisites for the
# current module.
$(config_target): $(module_prereqs) \
                  | $(call stampdir,$(MODULENAME)) \
                    $(module_builddir)

################################################################################
# clobber: - Current module clobber target
#
# Cleanup every module generated objects. Basically:
# * uninstall staged and bundled objects
# * remove the build directory
# * remove the stamp directory
################################################################################

.PHONY: clobber
clobber: | uninstall
	$(Q)$(call rmrf_cmd,$(module_builddir))
	$(Q)$(call rmrf_cmd,$(module_installdir))
	$(Q)rm -rf $(call stampdir,$(MODULENAME))

################################################################################
# build: - Current module build target
#
# Build current module intermediate objects.
#
# Depends on a completed build configuration.
################################################################################

build_target := $(call stamp,build)

.PHONY: build
build: $(build_target)

$(build_target): $(config_target)

################################################################################
# clean: - Current module clean target
#
# Cleanup module built, installed and bundled objects. Basically:
# * uninstall staged and bundled objects
# * run the module implementation's clean rule
# * remove the build stamp file
################################################################################
.PHONY: clean
clean: _clear_build_stamp | uninstall

.PHONY: _clear_build_stamp
_clear_build_stamp:
	$(Q)rm -f $(build_target)

################################################################################
# install: - Current module install target
#
# Stage current module objects.
#
# Depends on a completed build.
################################################################################

install_target   := $(call stamp,install)

.PHONY: install
install: $(install_target)

$(install_target): $(build_target) \
                   | $(module_installdir) $(stagingdir) $(hostdir)

################################################################################
# uninstall: - Current module uninstall target
#
# Cleanup module installed and bundled objects. Basically:
# * uninstall bundled objects
# * run the module implementation's uninstall rule
# * remove the install stamp file
################################################################################
.PHONY: uninstall
uninstall: _clear_install_stamp | drop

.PHONY: _clear_install_stamp
_clear_install_stamp:
	$(Q)rm -f $(install_target)

################################################################################
# bundle: - Current module bundle target
#
# Bundle current module objects.
#
# Depends on a completed install.
################################################################################

bundle_target := $(call stamp,bundle)

.PHONY: bundle
bundle: $(bundle_target)

$(bundle_target): $(install_target) | $(bundledir)

################################################################################
# drop: - Current module drop target
#
# Cleanup module bundled objects. Basically:
# * run the module implementation's drop rule
# * remove the bundle stamp file
################################################################################

.PHONY: drop
drop: _clear_bundle_stamp

.PHONY: _clear_bundle_stamp
_clear_bundle_stamp:
	$(Q)rm -f $(bundle_target)

################################################################################
# Various internal targets
################################################################################

_root_subdirs := bin etc include lib sbin share boot

# Internal directories creation target
$(addprefix $(stampdir),$(MODULES)) \
$(addprefix $(builddir),$(MODULES)) \
$(addprefix $(installdir),$(MODULES)) \
$(stagingdir) $(addprefix $(stagingdir)/,$(_root_subdirs)) \
$(hostdir) $(addprefix $(hostdir)/,$(_root_subdirs)) \
$(bundledir) $(bundle_rootdir):
	$(Q)$(call mkdir_cmd,$(@))

# Pattern rule creating stamp files.
$(call stampdir,$(MODULENAME))/%:
	$(Q)touch $(@)
