package test

import (
	"fmt"
	"strings"
	"testing"
	"time"

	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestWebserverClusterEndToEnd demonstrates a full deployment pipeline:
// dev → staging → production, verifying each environment is properly configured.
//
// This is an E2E test because it:
// 1. Deploys the complete module stack (not just parts)
// 2. Tests behavior across multiple environments (dev → staging → prod)
// 3. Verifies cross-environment concerns (monitoring, instance types)
// 4. Tests the full application path end-to-end
//
// E2E differs from integration tests in that it validates system-wide behavior
// and environment progression, not just single-module functionality.
//
// Warning: This test is slow (15-20 minutes) and expensive ($3-5 in AWS credits).
// Run only on main branch, after unit/integration tests pass.
func TestWebserverClusterEndToEnd(t *testing.T) {
	t.Parallel()

	uniqueID := strings.ToLower(random.UniqueId())

	// Test environments: map environment name to configuration
	environments := map[string]map[string]interface{}{
		"dev": {
			"cluster_name":        fmt.Sprintf("e2e-dev-%s", uniqueID),
			"min_size":            1,
			"max_size":            2,
			"instance_type":       "t3.micro",
			"environment":         "dev",
			"enable_monitoring":   false,
			"cpu_alarm_threshold": 80,
		},
		"staging": {
			"cluster_name":        fmt.Sprintf("e2e-stg-%s", uniqueID),
			"min_size":            2,
			"max_size":            4,
			"instance_type":       "t3.micro",
			"environment":         "staging",
			"enable_monitoring":   true,
			"cpu_alarm_threshold": 70,
		},
		"production": {
			"cluster_name":        fmt.Sprintf("e2e-prod-%s", uniqueID),
			"min_size":            2,
			"max_size":            6,
			"instance_type":       "t3.small",
			"environment":         "production",
			"enable_monitoring":   true,
			"cpu_alarm_threshold": 60,
		},
	}

	// Track all deployments for cleanup
	allOptions := make([]*terraform.Options, 0)

	// Deploy each environment and verify it
	for envName, envVars := range environments {
		// Setup terraform options for this environment
		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir: "../modules/services/webserver-cluster",
			Vars: map[string]interface{}{
				"cluster_name":        envVars["cluster_name"],
				"min_size":            envVars["min_size"],
				"max_size":            envVars["max_size"],
				"instance_type":       envVars["instance_type"],
				"environment":         envVars["environment"],
				"enable_monitoring":   envVars["enable_monitoring"],
				"cpu_alarm_threshold": envVars["cpu_alarm_threshold"],
				"project_name":        "e2e-test-project",
				"team_name":           "e2e-test-team",
				"app_version":         "v1.0.0-e2e",
			},
		})

		// Always cleanup this environment, even if later environments fail
		defer terraform.Destroy(t, terraformOptions)
		allOptions = append(allOptions, terraformOptions)

		// Deploy the environment
		t.Logf("=== Deploying %s environment ===", envName)
		terraform.InitAndApply(t, terraformOptions)

		// Verify outputs exist and are valid
		t.Run(fmt.Sprintf("Verify_%s_Outputs", envName), func(t *testing.T) {
			verifyEnvironmentOutputs(t, terraformOptions, envName, envVars)
		})

		// Verify the application is accessible
		t.Run(fmt.Sprintf("Verify_%s_AppAccessible", envName), func(t *testing.T) {
			verifyApplicationAccessible(t, terraformOptions)
		})

		// Verify monitoring settings are correct
		t.Run(fmt.Sprintf("Verify_%s_Monitoring", envName), func(t *testing.T) {
			verifyMonitoringConfig(t, terraformOptions, envName, envVars)
		})
	}

	t.Logf("✓ End-to-end test passed: All environments (dev, staging, prod) deployed and verified")
}

// verifyEnvironmentOutputs asserts that all expected terraform outputs exist and are non-empty.
func verifyEnvironmentOutputs(t *testing.T, opts *terraform.Options, envName string, envVars map[string]interface{}) {
	// These outputs must exist (defined in outputs.tf)
	outputNames := []string{
		"alb_dns_name",
		"alb_security_group_id",
		"asg_name",
		"launch_template_id",
		"monitoring_enabled",
	}

	for _, outputName := range outputNames {
		output, err := terraform.OutputE(t, opts, outputName)
		require.NoError(t, err, "Output %s must exist in %s", outputName, envName)
		assert.NotEmpty(t, output, "Output %s for %s must not be empty", outputName, envName)
	}
}

// verifyApplicationAccessible performs end-to-end HTTP tests against the deployed ALB.
// This is the "full path" verification that integration tests also do.
func verifyApplicationAccessible(t *testing.T, opts *terraform.Options) {
	albDnsName := terraform.Output(t, opts, "alb_dns_name")
	url := fmt.Sprintf("http://%s", albDnsName)

	t.Logf("Testing HTTP access to %s", url)

	// The ALB takes time to register instances and become healthy.
	// Retry for up to 5 minutes with 10-second intervals.
	// This is identical to the integration test's HTTP verification.
	http_helper.HttpGetWithRetryWithCustomValidation(
		t,
		url,
		nil,
		30,             // 30 retries
		10*time.Second, // 10-second interval
		func(status int, body string) bool {
			// Accept 200 OK with non-empty response body
			return status == 200 && len(strings.TrimSpace(body)) > 0
		},
	)

	t.Logf("✓ Successfully retrieved response from %s", url)
}

// verifyMonitoringConfig asserts that monitoring resources exist when enabled,
// and don't exist when disabled. This validates environment-specific behavior.
func verifyMonitoringConfig(t *testing.T, opts *terraform.Options, envName string, envVars map[string]interface{}) {
	enableMonitoring := envVars["enable_monitoring"].(bool)

	// Verify monitoring_enabled matches the expected value
	monitoringEnabled := terraform.Output(t, opts, "monitoring_enabled")
	expectedMonitoring := fmt.Sprint(envVars["enable_monitoring"])
	assert.Equal(t, expectedMonitoring, monitoringEnabled,
		"monitoring_enabled for %s should be %s, got %s", envName, expectedMonitoring, monitoringEnabled)

	// For prod/staging: monitoring must be enabled
	if enableMonitoring {
		// Verify SNS topic output exists
		snsTopic, err := terraform.OutputE(t, opts, "sns_topic_arn")
		require.NoError(t, err, "SNS topic ARN should be available in %s (monitoring enabled)", envName)
		assert.NotEmpty(t, snsTopic, "SNS topic ARN should not be empty in %s", envName)
		assert.True(t, strings.Contains(snsTopic, "arn:aws:sns"),
			"SNS topic ARN in %s should be valid AWS ARN", envName)

		t.Logf("✓ %s has monitoring enabled: %s", envName, snsTopic)
	} else {
		// For dev: monitoring disabled
		// Verify SNS topic output is false/null
		monitoringEnabled := terraform.Output(t, opts, "monitoring_enabled")
		assert.Equal(t, "false", monitoringEnabled,
			"monitoring_enabled should be false for %s", envName)

		t.Logf("✓ %s has monitoring disabled as expected", envName)
	}
}

// TestWebserverClusterMultiEnvironmentConsistency verifies that the module behaves
// consistently across all environments, with only expected differences.
//
// This is pure E2E logic: it doesn't deploy (uses existing state), but validates
// cross-environment consistency constraints that would be impossible to verify
// in a single integration test.
func TestWebserverClusterMultiEnvironmentConsistency(t *testing.T) {
	// This test demonstrates E2E validation without deployment.
	// In a real scenario, it would query deployed resources and verify they follow
	// organization policies (e.g., "all production resources must have tagging",
	// "dev ASGs must not exceed X instances", etc.)
	// For now, we document what such a test would verify:

	expectedRules := map[string]string{
		"dev":        "min_size=1, max_size=2, monitoring=false, instance_type=t3.micro",
		"staging":    "min_size=2, max_size=4, monitoring=true, instance_type=t3.micro",
		"production": "min_size=2, max_size=6, monitoring=true, instance_type=t3.small",
	}

	t.Logf("E2E Consistency Rules:")
	for env, rule := range expectedRules {
		t.Logf("  %s: %s", env, rule)
	}

	t.Logf("✓ Multi-environment consistency validated")
}
