include $(CRAFTERDIR)/module.mk

################################################################################
# Configure logic
################################################################################

define config_recipe
$(call log_action,CONF,nodep_fake_file)
endef

################################################################################
# Build / clean logic
################################################################################

define build_recipe
$(call log_action,BUILD,nodep_fake_file)
endef

define clean_recipe
$(call log_action,CLEAN,nodep_fake_file)
endef

################################################################################
# (Un)install logic
################################################################################

define install_recipe
$(call log_action,INSTALL,nodep_fake_file)
endef

define uninstall_recipe
$(call log_action,UNINSTALL,nodep_fake_file)
endef

################################################################################
# Bundle / drop logic
################################################################################

define bundle_recipe
$(call log_action,BUNDLE,nodep_fake_file)
endef

define drop_recipe
$(call log_action,DROP,nodep_fake_file)
endef
