# First source the user's main crafter customization makefile.
-include $(CONFIGDIR)/crafter.mk

################################################################################
# A set of helper macros and variables used by internal crafter logic.
#
# Platforms and Module implementation writers, as well as top-level project
# makefiles including bootstrap.mk are free to use them since these are
# included in every crafter makefiles.
#
# This file might be considered as provided some sort of basic crafter make
# API...
################################################################################

# CRAFTER_SCRIPTDIR - Path to the internal crafter script directory.
CRAFTER_SCRIPTDIR := $(CRAFTERDIR)/scripts

# Setup a few variables to handles verbosity.
# User may pass the V variable to enable verbose output on invocation command
# line
ifdef V
verbosity := V=$(V)
else
Q         := @
redirect  := >/dev/null
ifeq (,$(filter --no-print-directory,$(MAKEFLAGS)))
MAKEFLAGS += --no-print-directory
endif
endif

################################################################################
# A few special character definitions that may be used inside special macro
# invocations
################################################################################

# empty - Denotes a «null» / empty / void / non existing character
empty :=

# space - Denotes a space character
space := $(empty) $(empty)

# comma - Denotes a comma character
comma := ,

# newline - Denotes a new line character
define newline
$(empty)
$(empty)
endef

# echoe - Expand to a shell command suitable for echo'ing with escape sequence
#         interpretation enabled.
#
echoe := /bin/echo -e

################################################################################
# Dying handlers
################################################################################

# dieon_empty() - Interrupt make processing if variable given in argument is
#                 empty.
#
# $(1): name of variable to check
#
# Will stop processing with an error message if variable expands to an empty
# value or is composed of blank characters only.
define dieon_empty
$(if $($(strip $(1))),,$(error $(strip $(1) variable is empty !)))
endef

# dieon_undef() - Interrupt make processing if variable given in argument is
#                 undefined.
#
# $(1): name of variable to check
#
# Will stop processing with an error message if variable not defined so far.
define dieon_undef
$(if $(findstring undefined,$(origin $(strip $(1)))), \
     $(error $(strip $(1)) variable is undefined !))
endef

# dieon_undef_or_empty() - Interrupt make processing if variable given in
#                          argument is either undefined or empty.
#
# $(1): name of variable to check
#
# See dieon_undef() and dieon_empty() macros.
define dieon_undef_or_empty
$(call dieon_undef,$(1))$(call dieon_empty,$(1))
endef

# ifdef() - Expand if variable passed in argument is defined.
#
# $(1): name of variable to check
# $(2): parameter that will expanded if $(1) variable is defined.
define ifdef
$(if $(filter-out undefined,$(origin $(strip $(1)))),$(strip $(2)))
endef

################################################################################
# Console logging
################################################################################

# log_target() - Display a target related message for the current platform.
#
# $(1): module to log message for
# $(2): target type indicator
#
# The message will always be output whatever the state of verbosity handling.
define log_target
@printf "==========  %12.12s==%32.32s  %30.30s==\n" \
        "$(strip $(2))  ==========" \
        "$(if $(strip $(1)),  $(strip $(1))  )================================" \
        "[$(TARGET_BOARD):$(TARGET_FLAVOUR)]  ========================="
endef

# log_action() - Display a recipe action related message.
#
# $(1): action type indicator
# $(2): arbitrary message
#
# The message will output if verbosity is OFF, otherwise it will be inhibited.
define log_action
$(if $(Q),printf "%-9s %s\n" "$(strip $(1))" "$(strip $(2))",:)
endef

################################################################################
# Filesystem path handling
################################################################################

# find_first_path() - Given a list of directory search path, find the first
#                     existing filesystem path matching the basename passed in
#                     argument.
#
# $(1) filesystem path basename
# $(2) white-space separated filesystem directory search path
define find_first_path
$(word 1, $(realpath $(addsuffix /$(strip $(1)),$(strip $(2)))))
endef

# outdir - Expand to base output directory path for current platform.
define outdir
$(OUTDIR)/$(TARGET_BOARD)/$(TARGET_FLAVOUR)
endef

# stampdir() - Expand to timestamps directory path for current platform and
#              module passed in argument.
#
# $(1): module to return path for
#
# Timetamp files helps the Makefile logic to determine wether a particular
# target needs to be (re)built or not. They will be stored under this
# directory path on a per module basis.
define stampdir
$(outdir)/stamps/$(strip $(1))
endef

# builddir() - Expand to build directory path for current platform and module
#              passed in argument.
#
# $(1): module to return path for
#
# Intermediate module specific build objects will be constructed under this
# directory path.
define builddir
$(outdir)/build/$(strip $(1))
endef

# installdir - Expand to temporary install directory path for current platform.
#
# $(1): module to return path for
#
# Temporary staging objects will be installed under this directory path.
define installdir
$(outdir)/install/$(strip $(1))
endef

# stagingdir - Expand to staging directory path for current platform.
#
# Staging objects will be installed under this directory path.
define stagingdir
$(outdir)/staging
endef

# docdir - Expand to documentation directory path for current platform.
#
# Documentation should be installed under this directory path.
define docdir
$(outdir)/doc
endef

# bundledir - Expand to bundle directory path for current platform.
#
# Objects that are ready to be used outside of the build system will be placed
# under this directory path.
define bundledir
$(outdir)
endef

# bundle_rootdir - Expand to bundle root directory path for current platform.
#
# Final target runtime objects that are ready to be used outside of the build
# system will be placed under this directory path.
define bundle_rootdir
$(outdir)/root
endef

# bundle_fake_root_env - Path to fakeroot environment file used for bundle
#                        operations.
#
# See fakeroot(1) man page for more infos about fakeroot environment.
bundle_fake_root_env := $(outdir)/build/bundle_fakeroot.env

# hostdir - Expand to host tools directory path for current platform.
#
# Generated host tools will be placed under this directory path.
define hostdir
$(outdir)/host
endef

# boarddir - Expand to current platform board directory path.
#
# Board configuration objects and files will be searched for under this
# directory path.
define boarddir
$(PLATFORMDIR)/$(TARGET_BOARD)
endef

################################################################################
# Filesystem entry manipulation
################################################################################

# file_size() - Expand to size in bytes of file given in argument.
#
# $(1): path to file
define file_size
$(shell stat --dereference --format='%s' $(1))
endef

# chmod_cmd() - Expand to a shell command suitable for changing file
#               permissions.
#
# $(1): filesystem mode
# $(2): filesystem path
define chmod_cmd
$(call log_action,CHMOD,$(2)); \
chmod $(1) $(2)
endef

# mkdir_cmd() - Expand to a shell command suitable for creating a directory.
#
# $(1): path to directory to create
#
# Will also create every leading path components if needed.
define mkdir_cmd
$(call log_action,MKDIR,$(1)); \
mkdir -p $(strip $(1))
endef

# rmrf_cmd() - Expand to a shell command suitable for recursive directory
#              removal
#
# $(1): path to directory to remove
define rmrf_cmd
$(call log_action,RMRF,$(1)); \
rm -rf $(strip $(1))
endef

# rmf_cmd() - Expand to a shell command suitable for file removal
#
# $(1): path to file to remove
define rmf_cmd
$(call log_action,RMF,$(1)); \
rm -f $(strip $(1))
endef

# install_cmd() - Expand to a shell command suitable for filesystem entry
#                 install
#
# $(1): install command options
# $(2): path to source filesystem entry
# $(3): path to destination filesystem entry
define install_cmd
$(call log_action,INSTALL,$(3)); \
install $(1) $(2) $(3)
endef

# cp_cmd() - Expand to a shell command suitable for file copy
#
# $(1): source path
# $(2): destination path
define cp_cmd
$(call log_action,COPY,$(2)); \
cp $(1) $(2)
endef

# ln_cmd() - Expand to a shell command suitable for symbolic link creation
#
# $(1): path to filesystem entry target
# $(2): symbolic link path name
define ln_cmd
$(call log_action,LN,$(2)); \
ln -sf $(1) $(2)
endef

# lnck_cmd() - Expand to a shell command suitable symbolic link creation
#
# This command will check for target existence and, if existing, create the
# link. It will bail out with an error otherwise.
#
# $(1): path to filesystem entry target
# $(2): symbolic link path name
define lnck_cmd
$(call log_action,LNCK,$(2)); \
if [ -e "$(strip $(1))" ]; then \
	ln -sf $(1) $(2); \
else \
	echo 'lnck: $(strip $(1)): no such file or directory.' >&2; \
	exit 1; \
fi
endef

# untar_cmd() - Expand to a shell command suitable for extracting a tarball
#
# $(1): path to filesystem destination directory to extract into
# $(2): path to source tarball
#
# When extraction, the first leading file name component of each tarbal entry
# is stripped.
define untar_cmd
$(call log_action,UNTAR,$(1)); \
rm -rf $(1); \
mkdir -p $(1); \
tar --directory $(1) \
    --extract \
    --strip-components=1 \
    $(if $(Q),,--verbose) \
    --file $(2)
endef

# rsync_cmd() - Expand to a shell command suitable rsync operation
#
# $(1): path to filesystem source entry
# $(2): path to filesystem destination entry
#
# Operation is performed according to the following rules:
# * try to preserve write permissions
# * set read for owner, group and others
# * set exec permissions for owner, group and others:
# ** if source is a directory
# ** if source is a file with exec flag set
# * preserve owner and group if possible
# * preserve modification times
# * turn all source symbolic links as normal files
define rsync_cmd
$(call log_action,RSYNC,$(2)); \
rsync $(if $(Q),--quiet) \
      --perms \
      --chmod=ugo+rX \
      --owner \
      --group \
      --times \
      --copy-links \
      $(1) \
      $(2)
endef

# stage_lib_cmd() - Expand to a shell command suitable for installing a shared
#                   library file under the staging area.
#
# $(1): path to source library file to stage
# $(2): path to directory to store library file into
define stage_lib
dst_sofile="$(abspath $(strip $(2))/$(notdir $(1)))"; \
$(call log_action,STAGELIB,$$dst_sofile); \
if ! install -m755 -D $(1) "$$dst_sofile"; then \
	echo 'stage_lib: $(strip $(1)): install failed.' >&2; \
	exit 1; \
fi
endef

# mirror_cmd() - Expand to a shell command suitable for mirroring filesystem
#                entries
#
# $(1): path to source filesystem hierarchy
# $(2): path to destination filesystem hierarchy
#
# Source and destination parameters must be specified according to rsync
# expected usage: MIND SOURCE ARGUMENT TRAILING SLASHES !!!
# See section «USAGE» of rsync(1) man page for more infos.
#
# Implementation relies upon rsync used in update mode, i.e. skipping files that
# are newer on the destination side.
#
# Filesystem entry properties are preserved as much as possible with respect to
# current user permissions.
define mirror_cmd
$(call log_action,MIRROR,$(2)); \
rsync $(if $(Q),--quiet) \
      --archive \
      --update \
      $(1) \
      $(2)
endef

# unmirror_cmd() - Expand to a shell command suitable for removing filesystem
#                  entries mirrored by a previous mirror_cmd invocation.
#
# $(1): path to source filesystem hierarchy passed as first argument of
#       mirror_cmd macro
# $(2): path to destination filesystem hierarchy to cleanup
#
# The command will remove all filesystem entries from the $(2) destination
# path that are present under the $(1) source path.
define unmirror_cmd
$(call log_action,UNMIRROR,$(2)); \
if [ -d "$(2)" ]; then \
	if [ -d "$(1)" ]; then \
		cd $(2); \
		find $(1) ! -type d -printf "%P\n" | xargs rm -f; \
		for d in $$(find $(1) -type d -printf "%P\n" | \
		            sort --unique --reverse); do \
			if [ -d "$$d" ]; then \
				rmdir --ignore-fail-on-non-empty $$d; \
			fi \
		done \
	fi \
fi
endef

# add_unix_cred_cmd() - Expand to a shell command suitable for adding or
#                       replacing an entry into UNIX based credential file.
#
# $(1): path to unix credentials destination file
# $(2): credential string
#
# Generated / modified file as well as credential string is expected to comply
# with UNIX base system files as stated by group(5), passwd(5), gshadow(5) and
# shadow(5) manual pages.
define add_unix_cred_cmd
$(call log_action,ADDCRED,$(1)); \
sed -i \
    '/^$(firstword $(subst :, ,$(strip $(2)))):.\+/d;/^[[:blank:]]*$$/d' \
    $(1) 2>/dev/null || true; \
$(echoe) '$(strip $(subst $(newline),\n,$(2)))' >> $(1)
endef

# del_unix_cred_cmd() - Expand to a shell command suitable for removing
#                       an entry from UNIX based credential file (if existing).
#
# $(1): path to unix credentials destination file
# $(2): credential string given to add_unix_cred_cmd()
#
# Generated / modified file as well as credential string is expected to comply
# with UNIX base system files as stated by group(5), passwd(5), gshadow(5) and
# shadow(5) manual pages.
define del_unix_cred_cmd
$(call log_action,DELCRED,$(1)); \
sed -i \
    '/^$(firstword $(subst :, ,$(strip $(2)))):.\+/d;/^[[:blank:]]*$$/d' \
    $(1) 2>/dev/null || true
endef

# fake_root_cmd() - Expand to a shell command suitable for wrapping command in a
#                   fakeroot environment.
#
# $(1): path to fakeroot environment file
# $(2): shell command to wrap with fakeroot environment
#
# When the specified fakeroot environment file path is empty, this macro will
# generate an error since the environment is used to preserve faked filesystem
# hierarchy state across multiple fakeroot invocations.
#
# When the specified command parameter is empty, this macro will generate an
# error since fakeroot would spawn an interactive shell session otherwise...
#
# See fakeroot(1) man page for more infos about fakeroot environment.
define fake_root_cmd
$(if $(strip $(1)), \
     $(if $(strip $(2)), \
          fakeroot -s $(1) $(if $(realpath $(1)),-i $(1)) -- $(2), \
          $(error empty fakeroot command specified !)), \
     $(error empty fakeroot environment specified !))
endef

# bundle_cmd() - Expand to a shell command suitable for installing a
#                a file under the bundle area.
#
# $(1): options to give to install command
# $(2): path to source file to bundle
# $(3): path to directory to store file into
define bundle_cmd
dst_file="$(abspath $(strip $(3))/$(notdir $(2)))"; \
$(call log_action,BNDL,$$dst_file); \
if ! $(call fake_root_cmd, \
            $(bundle_fake_root_env), \
            install $(1) -D $(2) "$$dst_file"); then \
	echo 'bundle: $(strip $(2)): install failed.' >&2; \
	exit 1; \
fi
endef

# bundle_dir_cmd() - Expand to a shell command suitable for installing a
#                    a directory under the bundle area.
#
# $(1): options to give to install command
# $(2): path to directory to create
define bundle_dir_cmd
$(call log_action,BNDLDIR,$(strip $(2))); \
if ! $(call fake_root_cmd, \
            $(bundle_fake_root_env), \
            install $(1) -d $(2)); then \
	echo 'bundle: $(strip $(2)): install failed.' >&2; \
	exit 1; \
fi
endef

# drop_dir_cmd() - Expand to a shell command suitable for recursively removing a
#                  directory previously installed under the bundle area.
#
# $(1): path to previously installed directory
define drop_dir_cmd
$(call log_action,DROPDIR,$(1)); \
$(call fake_root_cmd,$(bundle_fake_root_env),rm -rf "$(strip $(1))")
endef

# bundle_bin_cmd() - Expand to a shell command suitable for installing a binary
#                    file under the bundle area.
#
# $(1): path to source binary file to bundle
# $(2): path to directory to store binary file into
define bundle_bin_cmd
dst_binfile="$(abspath $(strip $(2))/$(notdir $(1)))"; \
$(call log_action,BNDLBIN,$$dst_binfile); \
if ! $(call fake_root_cmd, \
            $(bundle_fake_root_env), \
            install --mode 755 -D $(1) "$$dst_binfile"); then \
	echo 'bundle_bin: $(strip $(1)): install failed.' >&2; \
	exit 1; \
fi; \
if ! $(call fake_root_cmd, \
            $(bundle_fake_root_env), \
            $(LIBC_CROSS_COMPILE)strip --strip-all "$$dst_binfile"); then \
    echo 'bundle_bin: $$dst_binfile: strip failed.' >&2; \
	exit 1; \
fi
endef

# bundle_ln_cmd() - Expand to a shell command suitable for installing a
#                   symbolic link file under the bundle area.
#
# $(1): path to filesystem entry target
# $(2): symbolic link path name
define bundle_ln_cmd
$(call log_action,BNDLLN,$(2)); \
if ! $(call fake_root_cmd, \
            $(bundle_fake_root_env), \
            ln -sf $(1) $(2)); then \
	echo 'bundle_link: $(strip $(2)): install failed.' >&2; \
	exit 1; \
fi
endef

# drop_cmd() - Expand to a shell command suitable for removing a
#              file previously installed under the bundle area.
#
# $(1): path to previously installed file
define drop_cmd
$(call log_action,DROP,$(1)); \
$(call fake_root_cmd,$(bundle_fake_root_env),rm -f "$(strip $(1))")
endef

# bundle_lib_nostrip_cmd() - Expand to a shell command suitable for installing
#                            an unstripped shared library file under the bundle
#                            area.
#
# $(1): path to source library file to bundle
# $(2): path to directory to store library file into
#
# Destination library file basename will be named after the ELF SONAME field
# embedded into the source library file to skip additional shared library
# links creation.
define bundle_lib_nostrip_cmd
if ! name=$$(env READELF=$(LIBC_CROSS_COMPILE)readelf \
             $(CRAFTER_SCRIPTDIR)/so_name.sh $(1)); then \
	echo 'bundle_lib: $(strip $(1)): invalid library.' >&2; \
	exit 1; \
fi; \
dst_sofile="$(strip $(2))/$$name"; \
$(call log_action,BNDLLIB,$$dst_sofile); \
if ! $(call fake_root_cmd, \
            $(bundle_fake_root_env), \
            install --mode 755 -D $(1) "$$dst_sofile"); then \
	echo 'bundle_lib: $(strip $(1)): install failed.' >&2; \
	exit 1; \
fi;
endef

# bundle_lib_cmd() - Expand to a shell command suitable for installing a shared
#                    library file under the bundle area.
#
# $(1): path to source library file to bundle
# $(2): path to directory to store library file into
#
# Destination library file basename will be named after the ELF SONAME field
# embedded into the source library file to skip additional shared library
# links creation.
define bundle_lib_cmd
if ! name=$$(env READELF=$(LIBC_CROSS_COMPILE)readelf \
             $(CRAFTER_SCRIPTDIR)/so_name.sh $(1)); then \
	echo 'bundle_lib: $(strip $(1)): invalid library.' >&2; \
	exit 1; \
fi; \
dst_sofile="$(strip $(2))/$$name"; \
$(call log_action,BNDLLIB,$$dst_sofile); \
if ! $(call fake_root_cmd, \
            $(bundle_fake_root_env), \
            install --mode 755 -D $(1) "$$dst_sofile"); then \
	echo 'bundle_lib: $(strip $(1)): install failed.' >&2; \
	exit 1; \
fi; \
if ! $(call fake_root_cmd, \
            $(bundle_fake_root_env), \
            $(LIBC_CROSS_COMPILE)strip --strip-unneeded "$$dst_sofile"); then \
	echo 'bundle_lib: $$dst_sofile: strip failed.' >&2; \
	exit 1; \
fi
endef

# drop_lib_cmd() - Expand to a shell command suitable for removing a shared
#                  library file previously bundled with bundle_lib_cmd().
#
# $(1): path to library file used as bundle_lib_cmd() $(1) parameter
# $(2): path to directory used as bundle_lib_cmd() $(2) parameter
define drop_lib_cmd
if [ ! -f "$(strip $(1))" ]; then \
	exit 0; \
fi; \
if ! name=$$(env READELF=$(LIBC_CROSS_COMPILE)readelf \
             $(CRAFTER_SCRIPTDIR)/so_name.sh $(1)); then \
	echo 'drop_lib: $(strip $(1)): invalid library.' >&2; \
	exit 1; \
fi; \
dst_sofile="$(strip $(2))/$$name"; \
$(call log_action,DROPLIB,$$dst_sofile); \
$(call fake_root_cmd,$(bundle_fake_root_env),rm -f "$$dst_sofile")
endef

# upper() - Convert string to upper case
#
# $(1): string
define upper
$(shell echo '$(1)' | tr '[:lower:]' '[:upper:]')
endef

# title_underline() - Convert string to underline with same size
#
# $(1): string
# $(2): char   - char ' and / are forbidden 
define title_underline
$(shell echo '$(1)' | sed 's/./$(2)/g')
endef

# echo_multi_line_var_cmd() - Verbatim multiline content generation command list
#
# $(1): multiline string
#
# Output a shell command suitable for generating verbatim multiline content from
# the string passed in argument.
# Content will be generated onto standard output.
#
# Warning:
# $(1) may contain escaped single quote as expected by the shell such as:
#   «it\'s a simple single quote example».
# As stated in the bash(1) man page, section «QUOTING»:
#   «Words of the form $'string' are treated specially. The word expands to
#    string, with backslash-escaped characters replaced as specified by the ANSI
#    C standard.»
# You will need an advanced shell for this feature to properly work. It is
# recommended to setup a target specific SHELL variable to bash for targets
# using this macro.
define echo_multi_line_var_cmd
$(echoe) $$'$(subst $(newline),\n,$(1))'
endef

# mkpasswd() - Expand to a shell command suitable for generating a passwd /
#              shadow file password
#
# $(1): options used by mkpasswd utility to encrypt the password.
# $(2): the password to encrypt in clear text
#
# Password will generated in a way that is suitable for embedding it directly
# into the 'encrypted password' field of shadow files using random salt and
# proper crypt compliant id string.
# See mkpasswd(1) and crypt(3) man pages for more infos.
#
# Warning! Giving an empty password as second argument will return an empty
#          string which, when used as an 'encrypted password' field will allow
#          login with no password at all !
define mkpasswd
$(strip $(if $(2),$(shell echo '$(2)' | mkpasswd $(1) --stdin $(3))))
endef

# gentmpl() - Expand to a shell command suitable for generating content out of a
#             template definition file and according to template configuration
#             variables.'
#
# $(1): path to output file
# $(2): path to template file
# $(3): template configuration variable specification(s)
#
# See $(CRAFTER_SCRIPTDIR)/gentmpl.py help message for more infos about
# configuration variable specification.
define gentmpl
$(call log_action,GENTMPL,$(1)); \
$(PYTHON) $(CRAFTER_SCRIPTDIR)/gentmpl.py --output "$(strip $(1))" "$(strip $(2))" $(3)
endef

# help_list_files() - Print align full path from $(base root directory)
#
# $(1): base root directory
# $(2): root directory
# $(3): Files list
define help_list_files
$(foreach f,$(sort $(strip $(3))),$(newline)  $$($(strip $(1)))$(strip $(2))/$(patsubst /%,%,$(f)))
endef

# help_bundle_files() - Print align full path from $(bundle_rootdir)
#
# $(1): root directory
# $(2): Files list
define help_bundle_files
$(call help_list_files,bundle_rootdir,$(strip $(1)),$(strip $(2)))
endef

# help_install_files() - Print align full path from $(stagindir)
#
# $(1): root directory
# $(2): Files list
define help_install_files
$(call help_list_files,stagingdir,$(strip $(1)),$(strip $(2)))
endef

define _help_render_vars

  .. code-block:: sh
$(shell split() { for i in "$$@"; do printf '\\n     %s' "$$i"; done; }; split $(1))
endef

# help_render_vars() - Parse split variable and print it one shell arguments by
#                      line.
#
# $(1): vars must be split
define help_render_vars
$(if $(strip $(1)),$(call _help_render_vars,$(1)),

  .. code-block:: sh

)
endef
