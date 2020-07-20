include $(CRAFTERDIR)/core/module.mk

$(call gen_module_depends,nodep)

################################################################################
# Configure logic
################################################################################

define config_recipe
$(call log_action,CONF,directdep_fake_file)
endef

################################################################################
# Build / clean logic
################################################################################

define build_recipe
$(call log_action,BUILD,directdep_fake_file)
endef

define clean_recipe
$(call log_action,CLEAN,directdep_fake_file)
endef

################################################################################
# (Un)install logic
################################################################################

define install_recipe
$(call log_action,INSTALL,directdep_fake_file)
endef

define uninstall_recipe
$(call log_action,UNINSTALL,directdep_fake_file)
endef

################################################################################
# Bundle / drop logic
################################################################################

define bundle_recipe
$(call log_action,BUNDLE,directdep_fake_file)
endef

define drop_recipe
$(call log_action,DROP,directdep_fake_file)
endef
