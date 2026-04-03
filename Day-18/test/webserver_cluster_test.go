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
)

// TestWebserverClusterUnit runs fast checks against the plan only.
// No real infrastructure is deployed. Runs in seconds.
// Use this on every pull request.
func TestWebserverClusterUnit(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../modules/services/webserver-cluster",
		Vars: map[string]interface{}{
			"cluster_name":        "unit-test-cluster",
			"instance_type":       "t3.micro",
			"min_size":            1,
			"max_size":            2,
			"environment":         "dev",
			"project_name":        "test-project",
			"team_name":           "test-team",
			"enable_monitoring":   false,
			"cpu_alarm_threshold": 80,
			"app_version":         "v1",
		},
		// PlanFilePath saves the plan to a file for assertion
		PlanFilePath: "/tmp/unit-test-plan.tfplan",
	})

	// Plan only — no apply, no real resources, no cost
	plan := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)

	// Assert the plan contains the expected resources
	terraform.RequirePlannedValuesMapKeyExists(t, plan, "aws_autoscaling_group.web")
	terraform.RequirePlannedValuesMapKeyExists(t, plan, "aws_lb.web")
	terraform.RequirePlannedValuesMapKeyExists(t, plan, "aws_launch_template.web")
	terraform.RequirePlannedValuesMapKeyExists(t, plan, "aws_security_group.alb_sg")
	terraform.RequirePlannedValuesMapKeyExists(t, plan, "aws_security_group.web_sg")
	terraform.RequirePlannedValuesMapKeyExists(t, plan, "aws_cloudwatch_log_group.web")

	// Assert SNS topic NOT planned when monitoring disabled
	_, snsExists := plan.ResourcePlannedValuesMap["aws_sns_topic.alerts[0]"]
	assert.False(t, snsExists, "SNS topic should not be planned when enable_monitoring = false")
}

// TestWebserverClusterIntegration deploys real infrastructure and
// verifies it actually works. Runs in 5-15 minutes. Incurs AWS costs.
// Run on merges to main only.
func TestWebserverClusterIntegration(t *testing.T) {
	t.Parallel()

	// Generate a unique ID so parallel test runs don't clash.
	// Without this two test runs would try to create resources
	// with the same name and one would fail.
	uniqueID := strings.ToLower(random.UniqueId())
	clusterName := fmt.Sprintf("test-%s", uniqueID)

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../modules/services/webserver-cluster",
		Vars: map[string]interface{}{
			"cluster_name":        clusterName,
			"instance_type":       "t3.micro",
			"min_size":            1,
			"max_size":            2,
			"environment":         "dev",
			"project_name":        "test-project",
			"team_name":           "test-team",
			"enable_monitoring":   false,
			"cpu_alarm_threshold": 80,
			"app_version":         "v1",
		},
	})

	// defer runs LAST — even if assertions panic or fail.
	// This guarantees real AWS resources are always destroyed
	// after the test. Without this a failed test leaves
	// running infrastructure and unexpected AWS costs.
	defer terraform.Destroy(t, terraformOptions)

	// Deploy real infrastructure
	terraform.InitAndApply(t, terraformOptions)

	// Get the ALB DNS name from outputs
	albDnsName := terraform.Output(t, terraformOptions, "alb_dns_name")
	url := fmt.Sprintf("http://%s", albDnsName)

	// Assert DNS name is not empty
	assert.NotEmpty(t, albDnsName, "ALB DNS name should not be empty")

	// Assert the app actually responds correctly.
	// Retries every 10 seconds for up to 5 minutes —
	// ALB takes time to register instances and pass health checks.
	// Without retry the test would fail immediately after apply
	// before instances are healthy.
	http_helper.HttpGetWithRetryWithCustomValidation(
		t,
		url,
		nil,
		30,             // max retries
		10*time.Second, // sleep between retries
		func(status int, body string) bool {
			// Assert HTTP 200 and body contains cluster name
			return status == 200 && strings.Contains(body, clusterName)
		},
	)

	// Assert monitoring resources not created
	// Only check sns_topic_arn if monitoring is actually enabled
	monitoringEnabled := terraform.Output(t, terraformOptions, "monitoring_enabled")
	assert.Equal(t, "false", monitoringEnabled, "Monitoring should be disabled for dev")

	// Assert correct instance type used
	instanceTypeUsed := terraform.Output(t, terraformOptions, "instance_type_used")
	assert.Equal(t, "t3.micro", instanceTypeUsed, "Dev environment should use t3.micro")

	// Assert correct log retention
	logRetention := terraform.Output(t, terraformOptions, "log_retention_days")
	assert.Equal(t, "7", logRetention, "Dev environment should have 7 day log retention")
}

// TestWebserverClusterProductionConfig verifies production-specific
// behaviour — larger instances, more instances, monitoring enabled.
func TestWebserverClusterProductionConfig(t *testing.T) {
	t.Parallel()

	uniqueID := strings.ToLower(random.UniqueId())
	clusterName := fmt.Sprintf("test-prod-%s", uniqueID)

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../modules/services/webserver-cluster",
		Vars: map[string]interface{}{
			"cluster_name":        clusterName,
			"min_size":            2,
			"max_size":            4,
			"environment":         "production",
			"project_name":        "test-project",
			"team_name":           "test-team",
			"enable_monitoring":   true,
			"cpu_alarm_threshold": 80,
			"app_version":         "v1",
		},
	})

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Assert production-specific outputs
	instanceTypeUsed := terraform.Output(t, terraformOptions, "instance_type_used")
	assert.Equal(t, "t3.small", instanceTypeUsed, "Production must use t3.small")

	logRetention := terraform.Output(t, terraformOptions, "log_retention_days")
	assert.Equal(t, "90", logRetention, "Production must have 90 day log retention")

	snsTopicArn := terraform.Output(t, terraformOptions, "sns_topic_arn")
	assert.NotEmpty(t, snsTopicArn, "SNS topic must exist in production")

	monitoringEnabled := terraform.Output(t, terraformOptions, "monitoring_enabled")
	assert.Equal(t, "true", monitoringEnabled, "Monitoring must be enabled in production")
}
