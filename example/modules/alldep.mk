include $(CRAFTERDIR)/module.mk

$(call gen_module_depends,$(MODULES))

define module_help
Ceci est un module de test
endef

################################################################################
# Configure logic
################################################################################

define config_recipe
$(call log_action,CONF,alldep_fake_file)
endef

################################################################################
# Build / clean logic
################################################################################

define build_recipe
$(call log_action,BUILD,alldep_fake_file)
endef

define clean_recipe
$(call log_action,CLEAN,alldep_fake_file)
endef

################################################################################
# (Un)install logic
################################################################################

define install_recipe
$(call log_action,INSTALL,alldep_fake_file)
endef

define uninstall_recipe
$(call log_action,UNINSTALL,alldep_fake_file)
endef

################################################################################
# Bundle / drop logic
################################################################################

define bundle_recipe
$(call log_action,BUNDLE,alldep_fake_file)
endef

define drop_recipe
$(call log_action,DROP,alldep_fake_file)
endef
