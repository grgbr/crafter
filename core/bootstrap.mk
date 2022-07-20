################################################################################
# Main crafter makefile defining top-level targets.
#
# Including this makefile into your project Makefile will expose crafter targets
# to the end user.
#
# You may safely include this in your project Makefile as long as you have :
# * previously defined the external make variables depicted below
# * defined a platform configuration hierarchy
#
# In addition, you may define additional targets, variables and macros in your
# project Makefile as long as they don't conflict with crafter internals.
################################################################################

# Disable parallel build for this invocation of make (also applies to your
# project makefile if it included this file).
#
# Rationals:
# ----------
#
# Simplify inter-module dependency handling.
#
# Allows to output meaningful progress message to the console to ease the
# debug of the project build logic without complex output synchronization and
# incurred display delays. For more on this, see section 5.4.1 of Gnu Make
# manual:
#     https://www.gnu.org/software/make/manual/html_node/Parallel-Output.html
#
# We won't benefit much of parallel build at this level anyway since crafter is
# targetting inter-module / top-level project integration builds.
.NOTPARALLEL:

# Disable default implicit pattern rules.
.SUFFIXES:

################################################################################
# External crafter variables definitions.
#
# These variables need to be set into your project makefile before including
# this file !
################################################################################

# OUTDIR - Path to directory where every crafter generated files will be stored.
#
# Will be created automatically if required.
#
# Must be set !
ifeq ($(OUTDIR),)
$(error Invalid OUTDIR specified !)
endif
OUTDIR := $(abspath $(strip $(OUTDIR)))

# CRAFTERDIR - Path to crafter directory.
#
# The parent of directory under which this makefile is located...
#
# Must exist !
CRAFTERDIR := $(realpath $(strip $(CRAFTERDIR)))
ifeq ($(CRAFTERDIR),)
$(error Invalid CRAFTERDIR specified !)
endif

# PLATFORMDIR - Path to root of platform configuration hierarchy.
#
# This is the location where your project defines platform specific build
# settings such as:
# * boards
# * build flavours
# * per-module settings
# * ...
#
# See section Registered platform probing logic below.
#
# Must exist !
PLATFORMDIR := $(realpath $(strip $(PLATFORMDIR)))
ifeq ($(PLATFORMDIR),)
$(error Invalid PLATFORMDIR specified !)
endif

# MODULEDIR - Path to directory where module implementations are found.
#
# This is the location where your project defines module implementations used by
# platforms defined into the platform configuration hierarchy.
#
# Modules are implemented using makefiles defining targets expected by crafter.
# See comments in module.mk file found under the crafter core logic directory.
#
# Must exist !
MODULEDIR := $(realpath $(strip $(MODULEDIR)))
ifeq ($(MODULEDIR),)
$(error Invalid MODULEDIR specified !)
endif

# TOPDIR - Path to your project top-level directory.
#
# Every build tasks crafter executes will be invoked from this directory.
#
# Taken as current directory if unspecified or invalid.
TOPDIR ?= $(CURDIR)
TOPDIR := $(realpath $(CURDIR))
ifeq ($(TOPDIR),)
$(error Invalid TOPDIR specified !)
endif

# Path to the user-specific XDG configuration directory as specified by the XDG
# Base Directory Specification:
#   https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
XDG_CONFIG_DIR := $(if $(XDG_CONFIG_HOME),$(XDG_CONFIG_HOME),$(HOME)/.config)

# Path to the user-specific crafter configuration directory where part of this
# build process may be overriden using makefiles stored there.
CONFIGDIR ?= $(XDG_CONFIG_DIR)/crafter

# Source common helper macros
include $(CRAFTERDIR)/core/helpers.mk

# Source main platform configuration file
include $(PLATFORMDIR)/config.mk

################################################################################
# Public bootstrap API.
#
# You can safely use these from your project makefiles including bootstrap.mk.
################################################################################

# if_platform_has_module() - Expand as 2nd passed argument if current platform
#                            depends on module given as first argument.
#
# $(1): module
# $(2): make expression
define if_platform_has_module
$(if $(filter $(1),$(_platform_modules)),$(2))
endef

################################################################################
# Define a few helpers needed for bootstrapping the build logic.
################################################################################

# _inspect_cmd() - Expand to a shell command suitable for crafter makefile
#                  inspection.
#
# $(1): path to makefile to inspect
# $(2): inspection target to operate
#
# See crafter core inspection makefile $(CRAFTERDIR)/core/inspect.mk for more
# infos.
define _inspect_cmd
$(MAKE) --silent \
        --makefile=$(CRAFTERDIR)/core/inspect.mk \
        TOPDIR:=$(TOPDIR) \
        CONFIGDIR:=$(CONFIGDIR) \
        OUTDIR:=$(OUTDIR) \
        PLATFORMDIR:=$(PLATFORMDIR) \
        CRAFTERDIR:=$(CRAFTERDIR) \
        MODULEDIR:=$(MODULEDIR) \
        MKFILE:=$(strip $(1)) \
        $(foreach v,$(CRAFTER_PLATFORM_VARS),$(v):="$($(v))") \
        $(2)
endef

# list_board_flavours() - Expand to a list of supported build flavours for the
#                         board given in argument.
# $(1): board
#
# Board flavours must be defined into $(PLATFORMDIR)/<board>/config.mk using the
# $(FLAVOUR) variable.
# Make will stop with an error if the definition in file mentionned above is
# invalid.
define list_board_flavours
$(sort \
  $(if $(realpath $(PLATFORMDIR)/$(strip $(1))/config.mk), \
       $(shell $(call _inspect_cmd, \
                      $(PLATFORMDIR)/$(strip $(1))/config.mk, \
                      show-FLAVOURS)), \
       $(error Missing '$(strip $(1))' board definition)))
endef

# _list_platform_modules_cmd() - Output a shell command suitable for listing
#                                modules a the current platform depends on.
#
# List is retrieved from the definition of the MODULES variable
# found into the flavour configuration file for the current board (see
# Registered platform probing logic above).
define _list_platform_modules_cmd
$(call _inspect_cmd, \
       $(PLATFORMDIR)/$(TARGET_BOARD)/$(TARGET_FLAVOUR).mk, \
       TARGET_BOARD:=$(TARGET_BOARD) \
       TARGET_FLAVOUR:=$(TARGET_FLAVOUR) \
       show-MODULES)
endef

# _list_platform_modules() - Expand to a list of modules a the current platform
#                            depends on.
#
# Module list will be stripped of leading and trailing blank characters and
# sorted in lexical order.
_list_platform_modules = $(sort $(shell $(call _list_platform_modules_cmd)))

# _list_module_depends_cmd() - Output a shell command suitable for listing
#                              dependency modules defined by a module.
# $(1): module
#
# Dependent modules will be listed for current platform.
define _list_module_depends_cmd
$(call _inspect_cmd, \
       $(MODULEDIR)/$(1).mk, \
       TARGET_BOARD:=$(TARGET_BOARD) \
       TARGET_FLAVOUR:=$(TARGET_FLAVOUR) \
       MODULENAME:=$(1) \
       list-module-depends)
endef

# _list_module_depends() - Expand to a list of dependency modules defined by a
#                          module.
#
# $(1): module
#
# Dependent modules will be listed for current platform.
_list_module_depends = $(shell $(call _list_module_depends_cmd,$(1)))

# _dieon_unknown_platform() - Stop make processing if current platform is
#                             invalid.
#
# Will bail out with an error message if one of $(TARGET_BOARD) or
# $(TARGET_FLAVOUR) is undefined or invalid.
define _dieon_unknown_platform
$(if $(filter $(TARGET_BOARD),$(BOARDS)), \
     $(if $(filter $(TARGET_FLAVOUR), \
                   $(call list_board_flavours,$(TARGET_BOARD))), \
          , \
          $(error Unknown specified '$(TARGET_FLAVOUR)' flavour !)), \
     $(error Unknown specified '$(TARGET_BOARD)' board !))
endef

# _warnon_unknown_platform() - Display a warning message if current platform is
#                              invalid.
#
# Warn only if at least one of $(TARGET_BOARD) or $(TARGET_FLAVOUR) is defined
# AND invalid.
define _warnon_unknown_platform
$(if $(TARGET_BOARD)$(TARGET_FLAVOUR), \
     $(if $(filter $(TARGET_BOARD),$(BOARDS)), \
          $(if $(filter $(TARGET_FLAVOUR), \
                        $(call list_board_flavours,$(TARGET_BOARD))), \
               , \
               $(warning Unknown specified '$(TARGET_FLAVOUR)' flavour !)), \
          $(warning Unknown specified '$(TARGET_BOARD)' board !)))
endef

# _break_words_cmd() - Expand to a shell command to place on a single line each
#                      space separated words from the string given in argument.
#
# $(1): string
_break_words_cmd = $(echoe) '$(subst $(space),\n,$(strip $(1)))'

# _indent_break_words_cmd() - Expand to a shell command to indent on a single
#                             line each space separated words from the string
#                             given in argument.
#
# $(1): string
_indent_and_break_words_cmd = $(echoe) '  $(subst $(space),\n  ,$(strip $(1)))'

################################################################################
# Registered platform probing logic.
#
# Registered platform definitions are retrieved from the platform configuration
# file hierarchy which should look something like:
#
#     $(PLATFORMDIR)/
#     |
#     --> config.mk                 <-- main platform configuration file
#     |
#     --> <first_board>/            <-- per-board sub-directory
#     |   |
#     |   --> config.mk             <-- board configuration file
#     |   |
#     |   --> <first_flavour>.mk    <-- flavour configuration file
#     |
#     |   ...
#     |
#     |   |
#         --> <last_flavour>.mk
#     ...
#
#     |
#     --> <last_board>/
#
# Basically, main platform configuration file MUST register boards by defining
# the BOARDS variable (see BOARDS above).
#
# Board configuration file MUST register supported build flavours by defining
# the FLAVOURS variable.
# The FLAVOURS variable is a list of space separated words. Each of them MUST
# point to a flavour configuration file present under the corresponding board
# sub-directory (minus the «.mk» extension).
#
# For each defined flavour, there MUST exist a flavour configuration file
# defining settings specific to the related flavour.
#
################################################################################

# BOARDS - List of build'able boards.
#
# This variable is a list of space separated words. Each of them MUST point to
# a platform board sub-directory as depicted above.
#
# Setup by main platform configuration file $(PLATFORMDIR)/config.mk.
# Board list will be stripped of leading and trailing blank characters and
# sorted in lexical order.
#
# If the main platform configuration file registered no board, bail out with an
# error.
override BOARDS := $(sort $(BOARDS))
ifeq ($(BOARDS),)
$(error Missing board list definition !)
endif

# _known_platforms - List of registered platform tuples.
#
# Registered platform definitions are retrieved from the platform configuration
# file hierarchy according to the following logic:
# * for each board defined into the main platform configuration file
# * look for a board configuration file
# * and get the supported build flavours definition from it.
#
# Will be stripped of leading and trailing blank characters and sorted in
# lexical order.
_known_platforms := $(sort \
                      $(foreach b, \
                                $(BOARDS), \
                                $(addprefix $(b)-, \
                                            $(call list_board_flavours,$(b)))))

# TARGET_PLATFORM - Current board and flavour combination.
#
# Tuple specifying the platform to build for. Must be defined according to the
# following scheme:
#   <board>-<flavour>
#
# Setup by end user (in order of precedence):
# * either by setting TARGET_PLATFORM directly on the command line, or
# * by setting both the TARGET_BOARD and TARGET_FLAVOUR directly on the command
#   line, or
# * by selecting a platform using the select-<board>-<flavour> make target.
#
# Will be stripped of leading and trailing blank characters.
override TARGET_PLATFORM := $(strip $(TARGET_PLATFORM))

# TARGET_BOARD - Current board.
#
# Component specifying the board part of the platform tuple
# (see TARGET_PLATFORM).
#
# Setup by end user (in order of precedence):
# * either by setting TARGET_PLATFORM directly on the command line, or
# * by setting TARGET_BOARD directly on the command line, or
# * by selecting a platform using the select-<board>-<flavour> make target.
#
# Will be stripped of leading and trailing blank characters.
override TARGET_BOARD := $(strip $(TARGET_BOARD))

# TARGET_FLAVOUR - Current build flavour.
#
# Component specifying the flavour part of the platform tuple
# (see TARGET_PLATFORM).
#
# Setup by end user (in order of precedence):
# * either by setting TARGET_PLATFORM directly on the command line, or
# * by setting TARGET_FLAVOUR directly on the command line, or
# * by selecting a platform using the select-<board>-<flavour> make target.
#
# Will be stripped of leading and trailing blank characters.
override TARGET_FLAVOUR := $(strip $(TARGET_FLAVOUR))

################################################################################
# Default platform detection logic
#
# Implement the first step of logic detecting the current platform specified by
# user:
# * if user specified platform on the command line, position TARGET_PLATFORM,
#   TARGET_BOARD and TARGET_FLAVOUR accordingly,
# * else rely upon default platform makefile content.
################################################################################

# _platform_mkfile_path - Path to default platform makefile.
#
# This makefile contains default platform tuple definition
# (see TARGET_PLATFORM).
#
# Setup by end user by selecting a platform using the select-<board>-<flavour>
# make target.
#
# It is sourced by the platform detection logic just below.
override _platform_mkfile_path := $(OUTDIR)/build/.crafter/platform.mk

ifeq ($(TARGET_PLATFORM),)
# User has specified no target platform on the command line. Let's try to devise
# one...

ifeq ($(TARGET_BOARD)$(TARGET_FLAVOUR),)
# User has specified neither a board nor a flavour on the command line : rely
# upon the default platform makefile if existing.
-include $(_platform_mkfile_path)
endif # ($(TARGET_BOARD)$(TARGET_FLAVOUR),)

ifneq ($(TARGET_BOARD)$(TARGET_FLAVOUR),)
# Board and / or flavour has been specified on the command line or through
# default platform makefile. Let's build the corresponding TARGET_PLATFORM
# tuple.
override TARGET_PLATFORM := $(TARGET_BOARD)-$(TARGET_FLAVOUR)
endif # ($(TARGET_BOARD)$(TARGET_FLAVOUR),)

else  # ! ($(TARGET_PLATFORM),)
# User has specified a target platform on the command line: derive board and
# flavour from the TARGET_PLATFORM tuple.

override TARGET_BOARD   := $(word 1,$(subst -, ,$(TARGET_PLATFORM)))
override TARGET_FLAVOUR := $(word 2,$(subst -, ,$(TARGET_PLATFORM)))

endif # ($(TARGET_PLATFORM),)

################################################################################
# Platform independent targets
################################################################################


# FORMAT_HELP - Function called to print help message
#
# Default case, just echo a multiline text
# Can setup by end user to use formatter like Pandoc.
# Sample:
#   define echo_rst_to_plain_cmd
#   $(call echo_multi_line_var_cmd,$(1)) | pandoc -s -f rst -t plain
#   endef
#   FORMAT_HELP := echo_rst_to_plain_cmd
FORMAT_HELP ?= echo_multi_line_var_cmd

# help_short_message - The default short help message
define help_short_message
$(call title_underline,BUILD_USAGE(1) $(VERSION) | $(@),=)
BUILD_USAGE(1) $(VERSION) | $(@)
$(call title_underline,BUILD_USAGE(1) $(VERSION) | $(@),=)

:Author:
:Date:

Targets
=======

Main targets
------------
Applicable to all platforms

list-boards
  display available build\'able boards

list-<BOARD>-flavours
  display build flavours available for **BOARD**

list-modules
  display all known modules

show-platform
  display default platform tuple

select-<BOARD>-<FLAVOUR>
  setup default platform using **BOARD** / **FLAVOUR** tuple

unselect-platform
  disable default platform setup

help
  a short help message

help-full
  a more complete help message


Platform targets
----------------
Applicable to default platform only !

all                      
  construct all modules

clobber                  
  remove all generated objects

show-modules             
  display modules the default platform depends on

list-variables           
  display a list of known public platform variables

show-variable-<VARIABLE> 
  display value of a known public platform variable

Module targets
--------------
Applicable to **MODULE** and default platform only !

<MODULE>
  construct

defconfig-<MODULE>
  setup default construction configuration **(forced)**

saveconfig-<MODULE>      
  save current construction configuration  **(forced)**

guiconfig-<MODULE>       
  run the GUI construction configurator    **(forced)**

config-<MODULE>          
  configure construction                   **(forced)**

build-<MODULE>           
  build intermediate objects               **(forced)**

install-<MODULE>         
  install final objects                    **(forced)**

bundle-<MODULE>          
  install deliverable objects              **(forced)**

drop-<MODULE>            
  remove bundled objects

uninstall-<MODULE>       
  *drop-<MODULE>* + remove staged objects

clean-<MODULE>           
  *uninstall-<MODULE>* + remove intermediate objects

clobber-<MODULE>         
  remove all generated objects

help-<MODULE>            
  display help message

Where
=====

BOARD
  a platform board as listed by the *list-boards* target

FLAVOUR
  a board specific build flavour as listed by the *list-<BOARD>-flavours* target

MODULE
  a default platform **MODULE** as listed by the *show-modules* target

VARIABLE
  a public variable known to the default platform as listed by the
  *list-variables* target
endef

# help: - Top level short help target.
#
# Simply display the content of the help_short_message variable (may be defined
# as a multiline makefile variable).
#
# Keep this target first as this should always be the default target.
#
# The echo_multi_line_var_cmd needs a bash shell to properly work
.PHONY: help
help: SHELL := /bin/bash
help:
	@$(call $(FORMAT_HELP),$(help_short_message))

define help_full_message
$(help_short_message)

Areas
=====
build
  directory under which intermediate built objects will be generated

  .. code:: sh

     $$(OUTDIR)/<BOARD>/<FLAVOUR>/build/<MODULE>/

staging
  directory under which final platform objects will be installed

  .. code:: sh

     $$(OUTDIR)/<BOARD>/<FLAVOUR>/staging/

bundle
  directory under which platform deliverables will be bundled

  .. code:: sh

     $$(OUTDIR)/<BOARD>/<FLAVOUR>/

Variables
=========
TARGET_PLATFORM
  override default platform using a tuple of the form: <**BOARD**>-<**FLAVOUR**>; 
  cannot be mixed with explicit **TARGET_BOARD** and / or **TARGET_FLAVOUR**
  definitions

TARGET_BOARD
  override default platform board ; in addition, **TARGET_FLAVOUR** MUST also
  be defined

TARGET_FLAVOUR
  override default platform flavour ; in additon, **TARGET_BOARD** MUST also
  be defined

OUTDIR
  directory path under which all crafter generated objects will be located
  $(call help_render_vars, $(OUTDIR))

PLATFORMDIR
  directory path under which crafter user / platform specific logic is located
  $(call help_render_vars, $(PLATFORMDIR))

MODULEDIR
  directory path under which user / platform module implementation makefiles are
  seached for
  $(call help_render_vars, $(MODULEDIR))

CRAFTERDIR
  directory path under which core crafter logic is located
  $(call help_render_vars, $(CRAFTERDIR))

CONFIGDIR
  directory path under which end-user configuration files are searched for
  $(call help_render_vars, $(CONFIGDIR))

V
  crafter verbosity setting 0 => quiet build (default), 1 => verbose build
endef

# help-full: - Top level full help target.
#
# Simply display the content of the help_full_message variable (may be defined
# as a multiline makefile variable).
#
# Keep this target first as this should always be the default target.
#
# The echo_multi_line_var_cmd needs a bash shell to properly work
.PHONY: help-full
help-full: SHELL := /bin/bash
help-full:
	@$(call $(FORMAT_HELP),$(help_full_message))

# list-boards: - display a list of build'able boards
#
# List of boards is retrieved from the $(BOARD) variable defined into main
# platform configuration file.
.PHONY: list-boards
list-boards:
	@$(call _break_words_cmd,$(BOARDS))

# list-modules: - Display a list of supported modules.
#
# List of modules is retrieved from the list of entries found under the modules
# directory $(MODULEDIR) and that end with a «.mk» extension.
#
# Note that, unlike the show-modules target, all known modules will be
# displayed.
_known_modules := $(sort $(subst .mk,,$(notdir $(wildcard $(MODULEDIR)/*.mk))))

.PHONY: list-modules
list-modules:
	@$(call _break_words_cmd,$(_known_modules))

# list-<board>-flavours: - Board flavours display targets.
#
# For each registered board, define a target of the form «list-<board>-flavours»
# that will display the list of build flavours supported by the given board.
_list_board_flavours_targets := \
	$(addprefix list-,$(addsuffix -flavours,$(BOARDS)))

.PHONY: $(_list_board_flavours_targets)
$(_list_board_flavours_targets):
	@$(call _break_words_cmd, \
	        $(call list_board_flavours,$(patsubst list-%-flavours,%,$(@))))

# select-<board>-<flavour>: - Select default platform targets.
#
# For each registered platform, define a target of the form
# «select-<board>-<flavour>» allowing to setup the current default platform
# tuple.
#
# The selected platform will be used for running platform dependent targets
# (e.g. build, install, ...) when user do not explicitly specify one on the
# command line (see default platform detection logic above).
#
# Basically, these targets populate the default platform makefile pointed to by
# the _platform_mkfile_path variable by defining the 2 components of a platform
# tuple: board and flavour.
# Board and flavour are respectively defined by the TARGET_BOARD and
# TARGET_FLAVOUR variables.
_select_platform_targets := $(addprefix select-,$(_known_platforms))

$(_select_platform_targets):
	@mkdir -p $(dir $(_platform_mkfile_path))
	@exec 1>$(_platform_mkfile_path); \
	 echo 'override TARGET_BOARD   := $(word 2,$(subst -, ,$(@)))'; \
	 echo 'override TARGET_FLAVOUR := $(word 3,$(subst -, ,$(@)))'

# unselect-platform: - Disable current default platform target.
#
# Remove current default platform. All subsequent invocation of platform
# dependent targets will have be passed a platform explicitly on the command
# line either by specifying the TARGET_PLATFORM or both the TARGET_BOARD and
# TARGET_FLAVOUR variables.
.PHONY: unselect-platform
unselect-platform:
	@rm -f $(_platform_mkfile_path)

# show-platform: - Display current default platform target.
#
# Display the current default platform on «none» if undefined.
# Will warn the user if the current default platform is invalid.
.PHONY: show-platform
show-platform:
	$(_warnon_unknown_platform)
	@echo $(if $(TARGET_PLATFORM),$(TARGET_PLATFORM),none)

################################################################################

# _platform_independent_targets - List of platform independent targets.
#
# A space separated list of targets not relying upon a valid platform tuple
# definition to run properly.
#
# Used for detecting if the user provided a valid platform when invoking targets
# that depends on a registered platform (e.g. build, install, ...)
#
# The purpose of this logic is to provide the user with a minimal set of targets
# allowing him to look for help and / or browse registered boards / flavours
# even if the default platform is invalid.
#
# This also allows the user to disable the default platform (using the
# unselect-platform target) or select a valid platform (using one of the
# select-<board>-<flavour> targets) even if the default platform is invalid.
# This case may arise when a former platform declared by the the default
# platform makefile refers to an invalid one because of a later modification
# of the platform configuration hierarchy.
_platform_independent_targets := help \
                                 help-full \
                                 list-boards \
                                 list-modules \
                                 $(_list_board_flavours_targets) \
                                 $(_select_platform_targets) \
                                 unselect-platform \
                                 show-platform

################################################################################
# Platform dependent targets
################################################################################

ifneq ($(filter-out $(_platform_independent_targets),$(MAKECMDGOALS)),)

# User requested a platform dependent target. Check if specified platform is
# registered and get out with an error message if not.
$(_dieon_unknown_platform)

# Compute the list of modules for the current platform.
#
# Module list will be stripped of leading and trailing blank characters and
# sorted in lexical order.
_platform_modules := $(_list_platform_modules)

# _module_help_msg() - Retrieve help message for the module given in argument.
#
# $(1): module
define _module_help_msg
$(shell $(call _inspect_cmd, \
               $(MODULEDIR)/$(1).mk, \
               TARGET_BOARD:=$(TARGET_BOARD) \
               TARGET_FLAVOUR:=$(TARGET_FLAVOUR) \
               show-module-help))
endef

# _module_help_cmd() - Display help message for the module given in argument.
#
# $(1): module
#
# Warning:
# _module_help_msg() expansion may contain escaped single quote as expected by
# the shell such as:
#   «it\'s a simple single quote example».
# As stated in the bash(1) man page, section «QUOTING»:
#   «Words of the form $'string' are treated specially. The word expands to
#    string, with backslash-escaped characters replaced as specified by the ANSI
#    C standard.»
# You will need an advanced shell for this feature to properly work. It is
# recommended to setup a target specific SHELL variable to bash for targets
# using this macro.
define _module_help_cmd
$(call title_underline,$(call upper,$(1))(1) $(VERSION) | $(1),=)
$(call upper,$(1))(1) $(VERSION) | $(1)
$(call title_underline,$(call upper,$(1))(1) $(VERSION) | $(1),=)

:Author:
:Date:

Description
===========
$(if $(call _module_help_msg,$(1)),$(call _module_help_msg,$(1)),No help provided.)

Dependencies
============
$(if $(call _list_module_depends,$(1)),$(shell \
  $(call _break_words_cmd,$(sort $(call _list_module_depends,$(1))))) \
  ,none)

Areas
=====
$$(hostdir)/
  Path to host tools directory
  $(call help_render_vars, $(hostdir))

$$(stagingdir)/
  Path to target objects directory
  $(call help_render_vars, $(stagingdir))

$$(bundledir)/
  Path to target deliverables directory
  $(call help_render_vars, $(bundledir))

$$(bundle_rootdir)/
  Path to target root FS hierarchy
  $(call help_render_vars, $(bundle_rootdir))

endef

# help-<module>: - Module display targets.
#
# For each module used by the current platform, define a target of the form
# «list-<module>» that will display the module help message.
#
# Targets will be executed within a bash shell process so that the
# echo_multi_line_var_cmd macro properly works (see _module_help_msg() macro).
_module_help_targets := $(addprefix help-,$(_platform_modules))

.PHONY: $(_module_help_targets)
$(_module_help_targets): SHELL := /bin/bash
$(_module_help_targets):
	@$(call $(FORMAT_HELP),$(call _module_help_cmd,$(subst help-,,$(@))))

# show-modules: - Target displaying a list of modules supported by the current
#                 platform.
.PHONY: show-modules
show-modules:
	@$(call _break_words_cmd,$(_platform_modules))

define _list_variables_cmd
$(call _inspect_cmd, \
       $(PLATFORMDIR)/$(TARGET_BOARD)/$(TARGET_FLAVOUR).mk, \
       TARGET_BOARD:=$(TARGET_BOARD) \
       TARGET_FLAVOUR:=$(TARGET_FLAVOUR) \
       list-vars)
endef

# list-variables: - Display list of known public variables.
#
# Will warn the user if the platform is undefined / invalid.
.PHONY: list-variables
list-variables:
	@$(call _break_words_cmd,$(sort $(shell $(call _list_variables_cmd))))

define _get_variable_cmd
$(call _inspect_cmd, \
       $(PLATFORMDIR)/$(TARGET_BOARD)/$(TARGET_FLAVOUR).mk, \
       TARGET_BOARD:=$(TARGET_BOARD) \
       TARGET_FLAVOUR:=$(TARGET_FLAVOUR) \
       show-$(1))
endef

# get_variable() - Expand to the value of the variable passed in argument.
#
# $(1): variable name
define get_variable
$(shell $(call _get_variable_cmd,$(1)))
endef

# show-variable-%: - Show value of a known public variable.
#
# If requested variable is undefined, display an empty string.
show-variable-%:
	@echo '$(call get_variable,$(subst show-variable-,,$(@)))'

# _platform_module_prereqs() - Expand to a list of prerequisites of module
#                              recipes generating objects.
#
# $(1): module
#
# List the prerequisites for the module given in argument and the current
# platform.
#
# As of today recipes generating objects are limited to config, build, install
# and bundle. Listed prerequisites are only applicable to these.
#
# Prerequisites are retrieved from the module implementation makefile invocation
# of the gen_module_depends() macro. Dependencies are restricted to known
# modules.
define _platform_module_prereqs
$(call _list_module_depends,$(1))
endef

# _platform_module_make_args() - Expant to the set of arguments passed to
#                                module make invocations
#
# This may seem quite a long list of arguments. The reason for this is that we
# don't want to export make variables to prevent from recursive invocation
# side effects.
#
# Note that this will be passed to the make eval function.
define _platform_module_make_args
--makefile=$(MODULEDIR)/$(1).mk \
TOPDIR:=$(TOPDIR) \
CONFIGDIR:=$(CONFIGDIR) \
OUTDIR:=$(OUTDIR) \
PLATFORMDIR:=$(PLATFORMDIR) \
CRAFTERDIR:=$(CRAFTERDIR) \
MODULEDIR:=$(MODULEDIR) \
TARGET_BOARD:=$(TARGET_BOARD) \
TARGET_FLAVOUR:=$(TARGET_FLAVOUR) \
$(foreach v,$(CRAFTER_PLATFORM_VARS),$(v):="$($(v))") \
MODULENAME:=$(1) \
$(if $(V),V=$(V))
endef

# _platform_module_rules() - Expand to a set of module rules suitable for latter
#                            evaluation.
#
# $(1): module
#
# Expand to a set of top-level rules for constructing objects of the module
# passed in argument.
#
# All generated targets will delegate construction task to the implementation
# module makefile found under the $(MODULEDIR) modules directory and named
# according to the following scheme:
#     <module>.mk
#
# The set of rules is meant to be given to the make eval function to generate
# final targets of the form:
# * config-<module>
# * clobber-<module>
# * build-<module>
# * clean-<module>
# * install-<module>
# * uninstall-<module>
# * bundle-<module>
# * drop-<module>
# * <module>
#
# Aside from <module> target, each of the above targets delegates its task to
# the <module>'s corresponding recipe.
# In addition, config, build, install and bundle targets are augmented with a
# prerequisite list computed using the _platform_module_prereqs() macro so that
# dependent module are garanteed to be constructed in order.
# All recipes mentionned above are executed even if the dependency resolution
# logic does not require it (by removing the corresponding stamp file).
#
# Finally, the <module> target will run the bundle-<module> target only if the
# dependency resolution logic requires it.
define _platform_module_rules
$(addsuffix -$(1),defconfig saveconfig guiconfig config build install bundle): \
	$(call _platform_module_prereqs,$(1))

.PHONY: $(1)
$(1): $(call _platform_module_prereqs,$(1))
	$(call log_target,$(1),ALL)
	$(Q)$$(MAKE) $(call _platform_module_make_args,$(1))

.PHONY: $(addsuffix -$(1), defconfig saveconfig guiconfig)
$(addsuffix -$(1),defconfig saveconfig guiconfig):
	$(call log_target,$(1),$$(call upper,$$(subst -$(1),,$$(@))))
	$(Q)$$(MAKE) $$(subst -$(1),,$$(@)) \
	             $(call _platform_module_make_args,$(1))

.PHONY: $(addsuffix -$(1),config build install bundle)
$(addsuffix -$(1),config build install bundle):
	$(call log_target,$(1),$$(call upper,$$(subst -$(1),,$$(@))))
	$(Q)rm -f $(call stampdir,$(1))/$$(subst -$(1),,$$(@))
	$(Q)$$(MAKE) $$(subst -$(1),,$$(@)) \
	             $(call _platform_module_make_args,$(1))

.PHONY: $(addsuffix -$(1), clobber clean uninstall drop)
$(addsuffix -$(1),clobber clean uninstall drop):
	$(call log_target,$(1),$$(call upper,$$(subst -$(1),,$$(@))))
	$(Q)$$(MAKE) $$(subst -$(1),,$$(@)) \
	             $(call _platform_module_make_args,$(1))

.PHONY: $(1)-%
$(1)-%:
	$(call log_target,$(1),$$(call upper,$$(subst $(1)-,,$$(@))))
	$(Q)$$(MAKE) $$(subst $(1)-,,$$(@)) \
	             $(call _platform_module_make_args,$(1))
endef

# The real work starts here: generate rules for each of the modules used by
# the current platform.
$(eval \
  $(foreach m, \
            $(_platform_modules), \
            $(call _platform_module_rules,$(m))$(newline)))

# all: - Target to construct the current platform entirely.
#
# Will only construct dependencies that are out of date.
.PHONY: all
all: $(_platform_modules)

# clobber: - Remove all objects generated for the current platform.
.PHONY: clobber
clobber:
	$(call log_target,,CLOBBER)
	$(Q)$(call rmrf_cmd,$(outdir))

endif # ($(filter-out $(_platform_independent_targets),$(MAKECMDGOALS)),)
