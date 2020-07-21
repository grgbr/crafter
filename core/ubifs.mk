include $(CRAFTERDIR)/core/fakefs.mk

################################################################################
# UBI FS and fakeroot utilities
################################################################################

# gen_ubifs_cmd() - UBIFS image generation command list
# $(1): path to output image file
# $(2): path to input fakeroot'ed directory
# $(3): path to fakeroot environment file associated with $(2)
# $(4): minimum I/O size
# $(5): physical erase block size
# $(6): maximum image size in number of erase blocks
# $(7): compression scheme
#
# Output a shell Command list suitable for building an UBIFS image from a
# directory hierarchy content and according to given I/O properties passed in
# argument.
#
# For a NAND flash, the following is assumed :
# * minimum I/O size:               NAND page size (eventually subpage size if
#                                   both driver and HW support it at runtime)
# * Logical Erase Block (LEB) size: Physical NAND erase block size minus twice
#                                   the "minimum I/O size" (required for
#                                   internal UBI bookkeeping purposes).
#
define gen_ubifs_cmd
$(call log_action,UBIFS,$(1)); \
mkubifs_opts="--min-io-size=$(strip $(4)) \
              --leb-size=$$(($(strip $(5)) - (2 * $(strip $(4))))) \
              --max-leb-cnt=$(strip $(6)) \
              --compr=$(strip $(7))"; \
env MKUBIFS=mkfs.ubifs \
	$(CRAFTER_SCRIPTDIR)/genubifs.sh --fake $(strip $(3)) \
	                                 --ubifs-opts "$${mkubifs_opts}" \
	                                 $(strip $(1)) \
	                                 $(strip $(2))
endef

################################################################################
# UBI FS generation logic
################################################################################

# _ubifs_rules() - Expand to a set of makefile rules required to generate
#                  UBI filesystem table and final image.
#
# $(1): basename of filesystem image to generate (and bundle)
# $(2): name of variable holding file system specification string
# $(3): minimum I/O size variable name
# $(4): physical erase block size variable name
# $(5): maximum image size in number of erase blocks variable name
# $(6): compression scheme variable name
define _ubifs_rules
# Interrupt processing if parameters are invalid.
$(foreach v,$(2) $(3) $(4) $(5) $(6),$(call dieon_undef_or_empty,$(v)))

# Generate filesystem table content
$(module_builddir)/fstable.txt: $(CRAFTERDIR)/core/ubifs.mk
	$(Q)$$(call gen_fstable_cmd,$$(@),$(strip $(2)))

# Bundle filesystem image
$(bundle_target): $(bundledir)/$(strip $(1))

# Generate filesystem image. Also ensure image is generated from an up to date
# fake root filesystem (which is generated at build time).
$(bundledir)/$(strip $(1)): $(module_builddir)/fakeroot.env | $(bundledir)
	$(Q)$$(call gen_ubifs_cmd, \
	           $$(@), \
	           $(module_builddir)/root, \
	           $(module_builddir)/fakeroot.env, \
	           $($(strip $(3))), \
	           $($(strip $(4))), \
	           $($(strip $(5))), \
	           $($(strip $(6))))

drop:
	$(Q)$(call rmf_cmd,$(bundledir)/$(strip $(1)))
endef

# gen_ubifs_rules() - Generate makefile rules required to generate UBI
#                     filesystem table and final image.
#
# $(1): basename of filesystem image to generate (and bundle)
# $(2): name of variable holding file system specification string
# $(3): minimum I/O size variable name
# $(4): physical erase block size variable name
# $(5): maximum image size in number of erase blocks variable name
# $(6): compression scheme variable name
define gen_ubifs_rules
$(eval $(call _ubifs_rules,$(1),$(2),$(3),$(4),$(5),$(6)))
endef

# The build target generate the fake root hierarchy.
$(build_target): $(module_builddir)/fakeroot.env

# Fake root hierarchy is generated from the filesytem table generated thanks to
# the _ubifs_rules() macro.
# For now, consider filesystem table source entries as relative to $(TOPDIR)
# directory.
$(module_builddir)/fakeroot.env: $(module_builddir)/fstable.txt \
                                 | $(module_builddir)/root
	$(Q)$(call gen_fakefs_cmd,$(|),$(<),$(@),$(TOPDIR))

# We need an advanced shell for the build recipe. See usage of gen_fstable_cmd()
# macro into _ubifs_rules().
$(module_builddir)/fstable.txt: SHELL := /bin/bash

# Make sure filesystem table is generated on dependency modules changes
$(module_builddir)/fstable.txt: $(module_prereqs) | $(module_builddir)

# gen_fakefs_cmd() expects an existing fake root top level directory.
$(module_builddir)/root:
	$(Q)$(call mkdir_cmd,$(@))

clean:
	$(Q)$(call rmrf_cmd,$(module_builddir))
