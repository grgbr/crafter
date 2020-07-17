################################################################################
# Core crafter inspection logic.
#
# Allows to inspect the content of a makefile from a separate make instance
# (i.e., without including it directly).
#
# Basically, this allows to fetch content of variables defined into other
# makefiles without risking namespace conflicts.
#
# See inspect_cmd() defined into core crafter helpers for an example of how to
# use this.
################################################################################

# No need for default implicit rules here.
.SUFFIXES:

# All targets will operate silently
.SILENT:

# Include the makefile to inspect.
include $(MKFILE)

# is_file_define() - Expand to non null string if the keyword given in argument
#                    is a make variable or macros defined in a makefile.
#
# $(1): keyword
#
# See section 8.10 of make manual for more infos:
# https://www.gnu.org/software/make/manual/html_node/Origin-Function.html
define is_file_define
$(if $(findstring file,$(origin $(1))),$(1))
endef

# list-module-depends: - Target displaying the modules the inspected module
#                        depends on.
#
# Dependencies are retrived from the content of _module_depends variable defined
# by a module implementation makefile call the gen_module_depends() macros.
#
# List will stripped of leading and trailing blanks.
list-module-depends:
	$(if $(_module_depends),$(info $(strip $(_module_depends))))

# show-module-help: - Target formating the module help message so that the
#                     latter can be fed to an echo command without loosing
#                     newlines.
show-module-help:
	$(if $(module_help),$(info $(subst $(newline),\n,$(module_help))))

# show-%: - Target displaying the unexpanded value of a variable defined in thee
#           the inspected makefile.
#
# See section 8.8 of make manual:
# https://www.gnu.org/software/make/manual/html_node/Value-Function.html
show-%:
	$(if $(call is_file_define,$(subst show-,,$(@))), \
	     $(info $(strip $(value $(subst show-,,$(@))))))
