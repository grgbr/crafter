################################################################################
# Autotools based module helpers.
#
# Implement the necessary logic used to ease the writing of Autotools based
# module rules. Allows to focus mainly on writing build logic instead of
# struggling with makefile constructs.  Include this file at the top of your
# module implementation Makefile.
#
# Basically this file provides:
# * a set of commands wrapping native Autotools generated Makefile targets
#   invocation in a way that is suitable to Crafter rules structure ;
# * a set of macros allowing to generate rules required for invoking native
#   Autotools targets from within a Crafter module.
#
# For each Crafter standard target you will find a correponding macro that will
# generate required rules. These macros must be given, as parameter, the name of
# a variable holding the target specific recipe (block of commands). Theses
# macros are named according to the following scheme:
#   autotools_gen_<crafter_target>_rule[s]
#
# On a per-target basis, module writer may arbitrarily choose to use these
# macros from within module Makefile, or to write his own Makefile constructs to
# address a specific target requirement.
################################################################################

################################################################################
# Autotools related commands.
#
# Use theses from within module recipes to implement Autotools based module
# build.
################################################################################

# autotools_target_autoreconf() - Expand to a shell construct allowing to remake
#                                 Autotools files under a source directory tree
#                                 recursively.
# $(1): path to source directory
# $(2): path to toolchain autoreconf
# $(3): autotools environment variables to invoke autoreconf with
#
# Needed when a source tree is distributed along with its own generated internal
# Autotools files (Makefile.am, Makefile.in, configure, etc...) using a set of
# outdated Autotools or not suitable for cross-compiling (mostly because of
# libtool mayhem...).
# This command will force generation of an entirely brand new set of Autotools
# files using path to binaries given by $(3) argument. Usual related
# environment variables include:
# - AUTOCONF
# - AC_MACRODIR
# - AUTOHEADER
# - AUTOM4TE
# - AUTOM4TE_NO_FATAL
# - AUTOM4TE_DEBUG
# - AUTOMAKE
# - AUTOMAKE_LIBDIR
# - ACLOCAL
# - ACLOCAL_PATH
# - ACLOCAL_AUTOMAKE_DIR
# - LIBTOOLIZE
# - LIBTOOL
#
# See autoreconf(1), autoconf(1), automake(1), autoreconf(1), autoupdate(1),
# autoheader(1), autoscan(1), libtool(1) man pages for more infos.
define autotools_target_autoreconf
$(call log_action,ARECONF,$(1)) && \
cd $(1) && \
env $(3) $(2) --force \
              --install \
              $(if $(Q), \
                   --warnings=none, \
                   --verbose --warnings=all) \
              $(redirect) && \
rm -rf $$(find $(strip $(1)) -type d -name autom4te.cache) && \
rm -rf $$(find $(module_builddir) -type d -name autom4te.cache)
endef

# autotools_target_configure() - Expand to a shell construct suitable for
#                                running the Autotools based current module
#                                targetconfigure operation.
# $(1): path to source directory
# $(2): autotools arguments to invoke configure with
#
# Configure the build of current module for out-of-tree build and according to
# arguments given as $(2) parameter.
define autotools_target_configure
$(call log_action,ACONF,$(module_builddir)) && \
cd $(module_builddir) && \
$(1)/configure \
	--with-sysroot=$(stagingdir) \
	--cache=$(module_builddir)/autom4te.cache \
	$(if $(Q),--quiet) \
	$(2)
endef

# autotools_host_configure() - Expand to a shell construct suitable for
#                              running the Autotools based current module
#                              host configure operation.
# $(1): path to source directory
# $(2): autotools arguments to invoke configure with
#
# Configure the build of current module for out-of-tree build and according to
# arguments given as $(2) parameter.
define autotools_host_configure
$(call log_action,ACONF,$(module_builddir)) && \
cd $(module_builddir) && \
$(1)/configure \
	--prefix=$(hostdir) \
	--cache=$(module_builddir)/autom4te.cache \
	$(XTCHAIN_AUTOTOOLS_HOST_CONFIGURE_ARGS) \
	$(if $(Q),--quiet) \
	$(2)
endef

# autotools_target_make() - Expand to a shell command allowing to run an
#                           Autotools based target make operation for current
#                           module.
# $(1): autotools make targets
# $(2): autotools arguments to invoke make with
define autotools_target_make
$(MAKE) -C $(module_builddir) \
        $(1) \
        $(2) \
        $(if $(Q), \
             LIBTOOLFLAGS:="--quiet", \
             LIBTOOLFLAGS:="--verbose") \
        $(verbosity)
endef

# autotools_host_make() - Expand to a shell command allowing to run an
#                         Autotools based host make operation for current
#                         module.
# $(1): autotools make targets
# $(2): autotools arguments to invoke make with
define autotools_host_make
$(MAKE) -C $(module_builddir) \
        $(1) \
        $(2) \
        $(if $(Q), \
             LIBTOOLFLAGS:="--quiet", \
             LIBTOOLFLAGS:="--verbose") \
        $(verbosity)
endef

################################################################################
# Autotools rules handling
################################################################################

define _autotools_config_rules
$(config_target): $(call stamp,bootstrap)
	$$($(strip $(1)))
	$(Q)touch $$(@)

$(call stamp,bootstrap): $(module_prereqs) \
                         $(CRAFTERDIR)/core/autotools.mk \
                         | $(call stampdir,$(MODULENAME)) \
                           $(module_builddir)
	$$($(strip $(2)))
	$(Q)touch $$(@)
endef

# autotools_gen_config_rules() - Generate rules required for calling Autotools
#                                based configuration target.
#
# $(1): name of autotools configure recipe variable
# $(2): name of optional autotools autoreconf recipe variable
define autotools_gen_config_rules
$(eval $(call _autotools_config_rules,$(1),$(2)))
endef

define _autotools_build_rule
$(build_target):
	$$($(strip $(1)))
	$(Q)touch $$(@)
endef

# autotools_gen_build_rule() - Generate rules required for calling Autotools
#                              based build target.
#
# $(1): name of autotools build recipe variable
define autotools_gen_build_rule
$(eval $(call _autotools_build_rule,$(1)))
endef

define _autotools_clean_rule
clean:
	$(if $(realpath $(config_target)),-$$($(strip $(1))))
endef

# autotools_gen_clean_rule() - Generate rules required for calling Autotools
#                              based clean target.
#
# $(1): name of autotools clean recipe variable
define autotools_gen_clean_rule
$(eval $(call _autotools_clean_rule,$(1)))
endef

define _autotools_install_rule
$(install_target):
	$$($(strip $(1)))
	$(Q)touch $$(@)
endef

# autotools_gen_install_rule() - Generate rules required for calling Autotools
#                                based install target.
#
# $(1): name of autotools install recipe variable
define autotools_gen_install_rule
$(eval $(call _autotools_install_rule,$(1)))
endef

define _autotools_uninstall_rule
uninstall:
	$(if $(realpath $(config_target)),-$$($(strip $(1))))
endef

# autotools_gen_uninstall_rule() - Generate rules required for calling Autotools
#                                  based uninstall target.
#
# $(1): name of autotools uninstall recipe variable
define autotools_gen_uninstall_rule
$(eval $(call _autotools_uninstall_rule,$(1)))
endef

define _autotools_bundle_rule
$(bundle_target):
	$$($(strip $(1)))
	$(Q)touch $$(@)
endef

# autotools_gen_bundle_rule() - Generate rules required for calling Autotools
#                               based bundle target.
#
# $(1): name of autotools bundle recipe variable
define autotools_gen_bundle_rule
$(eval $(call _autotools_bundle_rule,$(1)))
endef

define _autotools_drop_rule
drop:
	$(if $(realpath $(config_target)),$$($(strip $(1))))
endef

# autotools_gen_drop_rule() - Generate rules required for calling Autotools
#                             based drop target.
#
# $(1): name of autotools drop recipe variable
define autotools_gen_drop_rule
$(eval $(call _autotools_drop_rule,$(1)))
endef
