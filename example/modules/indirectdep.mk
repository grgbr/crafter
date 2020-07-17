include $(CRAFTERDIR)/module.mk

$(call gen_module_depends,directdep)

################################################################################
# Configure logic
################################################################################

define config_recipe
$(call log_action,CONF,indirectdep_fake_file)
endef

################################################################################
# Build / clean logic
################################################################################

define build_recipe
$(call log_action,BUILD,indirectdep_fake_file)
endef

define clean_recipe
$(call log_action,CLEAN,indirectdep_fake_file)
endef

################################################################################
# (Un)install logic
################################################################################

define install_recipe
$(call log_action,INSTALL,indirectdep_fake_file)
endef

define uninstall_recipe
$(call log_action,UNINSTALL,indirectdep_fake_file)
endef

################################################################################
# Bundle / drop logic
################################################################################

define bundle_recipe
$(call log_action,BUNDLE,indirectdep_fake_file)
endef

define drop_recipe
$(call log_action,DROP,indirectdep_fake_file)
endef
