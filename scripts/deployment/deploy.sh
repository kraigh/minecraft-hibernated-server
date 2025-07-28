#!/bin/bash
# deploy.sh - Deploy CloudFormation stack for minecraft-hibernated-server

set -e

# Default values
STACK_NAME="minecraft-hibernated-server"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
TEMPLATE_FILE="cloudformation/main.yaml"
CONFIG_FILE="cloudformation/parameters.json"
S3_BUCKET=""
CREATE_BUCKET=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -s, --stack-name NAME     CloudFormation stack name (default: minecraft-hibernated-server)"
    echo "  -r, --region REGION       AWS region (default: us-east-1 or \$AWS_DEFAULT_REGION)"
    echo "  -p, --parameters FILE     Parameters file (default: cloudformation/parameters.json)"
    echo "  -b, --s3-bucket BUCKET    S3 bucket for templates (will be created if doesn't exist)"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Deploy with defaults"
    echo "  $0 -s my-minecraft -r us-west-2      # Custom stack name and region"
    echo "  $0 -b my-templates-bucket             # Use specific S3 bucket"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--stack-name)
            STACK_NAME="$2"
            shift 2
            ;;
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -p|--parameters)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -b|--s3-bucket)
            S3_BUCKET="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}ERROR: AWS CLI is not installed. Please install it first.${NC}"
    echo "See: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

# Check jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}ERROR: jq is not installed. Please install it first.${NC}"
    echo "On macOS: brew install jq"
    echo "On Ubuntu/Debian: sudo apt-get install jq"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}ERROR: AWS credentials not configured. Please run 'aws configure' first.${NC}"
    exit 1
fi

# Check if required files exist
if [[ ! -f "$TEMPLATE_FILE" ]]; then
    echo -e "${RED}ERROR: Template file '$TEMPLATE_FILE' not found.${NC}"
    exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${YELLOW}Parameters file '$CONFIG_FILE' not found.${NC}"
    echo "The parameters file exists but may need editing. Please review and update with your values."
    exit 1
fi

# Validate parameters file has required values
REQUIRED_PARAMS=("KeyPairName" "HomeIP" "GitRepoUrl")
for param in "${REQUIRED_PARAMS[@]}"; do
    PARAM_VALUE=$(jq -r ".[] | select(.ParameterKey == \"$param\") | .ParameterValue" "$CONFIG_FILE")
    if [[ -z "$PARAM_VALUE" || "$PARAM_VALUE" == "null" || "$PARAM_VALUE" == "" ]]; then
        echo -e "${RED}ERROR: Required parameter '$param' is missing or empty in $CONFIG_FILE${NC}"
        echo "Please edit the parameters file with your actual values."
        exit 1
    fi
    
    # Check for placeholder values
    case $param in
        "KeyPairName")
            if [[ "$PARAM_VALUE" == *"your-key"* || "$PARAM_VALUE" == *"my-minecraft-key"* ]]; then
                echo -e "${YELLOW}WARNING: Parameter '$param' appears to be a placeholder value: $PARAM_VALUE${NC}"
            fi
            ;;
        "HomeIP")
            if [[ "$PARAM_VALUE" == *"203.0.113"* || "$PARAM_VALUE" == *"1.2.3.4"* ]]; then
                echo -e "${YELLOW}WARNING: Parameter '$param' appears to be a placeholder value: $PARAM_VALUE${NC}"
                echo "Get your real IP from: https://whatismyipaddress.com/"
            fi
            ;;
        "GitRepoUrl")
            if [[ "$PARAM_VALUE" == *"yourusername"* || "$PARAM_VALUE" == *"kraigh"* ]]; then
                echo -e "${YELLOW}WARNING: Parameter '$param' should point to YOUR fork: $PARAM_VALUE${NC}"
            fi
            ;;
    esac
done

echo -e "${BLUE}🎮 Minecraft Hibernated Server Deployment${NC}"
echo "Stack Name: $STACK_NAME"
echo "Region: $REGION"
echo "Template: $TEMPLATE_FILE"
echo "Parameters: $CONFIG_FILE"
echo ""

# Create or use S3 bucket for templates
if [[ -z "$S3_BUCKET" ]]; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    S3_BUCKET="${STACK_NAME}-templates-${ACCOUNT_ID}-${REGION}"
    CREATE_BUCKET=true
fi

echo "S3 Bucket for templates: $S3_BUCKET"

# Create S3 bucket if needed
if [[ "$CREATE_BUCKET" == "true" ]]; then
    if ! aws s3 ls "s3://$S3_BUCKET" &> /dev/null; then
        echo -e "${YELLOW}Creating S3 bucket for CloudFormation templates...${NC}"
        if [[ "$REGION" == "us-east-1" ]]; then
            aws s3 mb "s3://$S3_BUCKET" --region "$REGION"
        else
            aws s3 mb "s3://$S3_BUCKET" --region "$REGION" --create-bucket-configuration LocationConstraint="$REGION"
        fi
        
        # Enable versioning
        aws s3api put-bucket-versioning \
            --bucket "$S3_BUCKET" \
            --versioning-configuration Status=Enabled
    fi
fi

# Upload nested templates to S3
echo -e "${BLUE}Uploading CloudFormation templates to S3...${NC}"
aws s3 sync cloudformation/ "s3://$S3_BUCKET/" --exclude="parameters.json" --exclude="main-stack.yaml"

# Package the main template (this handles nested stack template URLs)
echo -e "${BLUE}Packaging main template...${NC}"
aws cloudformation package \
    --template-file "$TEMPLATE_FILE" \
    --s3-bucket "$S3_BUCKET" \
    --output-template-file /tmp/packaged-template.yaml \
    --region "$REGION"

echo ""
echo -e "${BLUE}Validating CloudFormation template...${NC}"
aws cloudformation validate-template \
    --template-body file:///tmp/packaged-template.yaml \
    --region "$REGION" > /dev/null

echo -e "${GREEN}✅ Template validation successful!${NC}"
echo ""

# Convert parameters from JSON array format to CloudFormation parameter format
echo -e "${BLUE}Processing parameters...${NC}"
PARAMETER_OVERRIDES=$(jq -r '.[] | "\(.ParameterKey)=\(.ParameterValue)"' "$CONFIG_FILE" | tr '\n' ' ')

echo -e "${BLUE}Deploying CloudFormation stack...${NC}"
echo -e "${YELLOW}This may take 10-15 minutes to complete...${NC}"
echo ""

# Deploy the stack
aws cloudformation deploy \
    --template-file /tmp/packaged-template.yaml \
    --stack-name "$STACK_NAME" \
    --parameter-overrides $PARAMETER_OVERRIDES \
    --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
    --region "$REGION" \
    --no-fail-on-empty-changeset

# Check deployment status
if [[ $? -eq 0 ]]; then
    echo ""
    echo -e "${GREEN}🎉 Deployment successful!${NC}"
    echo ""
    echo -e "${BLUE}=== Stack Outputs ===${NC}"
    
    # Get stack outputs in a nice format
    aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query 'Stacks[0].Outputs[?OutputKey!=`DeploymentInstructions`].[OutputKey,OutputValue,Description]' \
        --output table

    echo ""
    echo -e "${BLUE}=== Next Steps ===${NC}"
    
    # Get deployment instructions
    INSTRUCTIONS=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`DeploymentInstructions`].OutputValue' \
        --output text)
    
    if [[ -n "$INSTRUCTIONS" ]]; then
        echo "$INSTRUCTIONS"
    else
        echo -e "${GREEN}1. Wait 5-10 minutes for all instances to complete initialization${NC}"
        echo -e "${GREEN}2. Connect your Minecraft client to the connection endpoint above${NC}"
        echo -e "${GREEN}3. The server will start when you connect (may take 60-90 seconds)${NC}"
        echo -e "${GREEN}4. Access the web management interface using the Cockpit URL${NC}"
        echo -e "${GREEN}5. The server will hibernate after 20 minutes of inactivity${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}💡 Tip: Use './scripts/deployment/update-stack.sh' to update your deployment later${NC}"
    
else
    echo ""
    echo -e "${RED}❌ Deployment failed!${NC}"
    echo "Check the CloudFormation console for detailed error information:"
    echo "https://${REGION}.console.aws.amazon.com/cloudformation/home?region=${REGION}#/stacks"
    exit 1
fi