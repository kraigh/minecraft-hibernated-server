#!/bin/bash
# update-stack.sh - Update existing CloudFormation stack

set -e

STACK_NAME="minecraft-hibernated-server"
TEMPLATE_FILE="cloudformation/main-stack.yaml"
PARAMS_FILE="cloudformation/parameters.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔄 Updating Minecraft Hibernated Server Stack${NC}"
echo

# Check if stack exists
if ! aws cloudformation describe-stacks --stack-name $STACK_NAME > /dev/null 2>&1; then
    echo -e "${RED}❌ Stack '$STACK_NAME' not found${NC}"
    echo "Use deploy.sh to create the stack first."
    exit 1
fi

# Check parameters file
if [ ! -f "$PARAMS_FILE" ]; then
    echo -e "${RED}❌ Parameters file not found: $PARAMS_FILE${NC}"
    exit 1
fi

# Validate template
echo "Validating CloudFormation template..."
aws cloudformation validate-template --template-body file://$TEMPLATE_FILE > /dev/null
echo -e "${GREEN}✅ Template validation passed${NC}"

# Preview changes (optional)
echo -e "${YELLOW}📋 Would you like to preview changes first? (y/N): ${NC}"
read -r preview
if [[ "$preview" =~ ^[Yy]$ ]]; then
    echo "Creating change set..."
    aws cloudformation create-change-set \
        --stack-name $STACK_NAME \
        --template-body file://$TEMPLATE_FILE \
        --parameters file://$PARAMS_FILE \
        --capabilities CAPABILITY_IAM \
        --change-set-name "preview-$(date +%s)"
    
    echo "Describing change set..."
    CHANGE_SET_NAME=$(aws cloudformation list-change-sets --stack-name $STACK_NAME --query 'Summaries[0].ChangeSetName' --output text)
    aws cloudformation describe-change-set --stack-name $STACK_NAME --change-set-name $CHANGE_SET_NAME
    
    echo -e "${YELLOW}Continue with update? (y/N): ${NC}"
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Update cancelled."
        # Clean up change set
        aws cloudformation delete-change-set --stack-name $STACK_NAME --change-set-name $CHANGE_SET_NAME
        exit 0
    fi
fi

# Update stack
echo "Updating CloudFormation stack: $STACK_NAME"
aws cloudformation deploy \
    --template-file $TEMPLATE_FILE \
    --stack-name $STACK_NAME \
    --parameter-overrides file://$PARAMS_FILE \
    --capabilities CAPABILITY_IAM \
    --no-fail-on-empty-changeset

if [ $? -eq 0 ]; then
    echo -e "${GREEN}🎉 Update successful!${NC}"
    
    # Show updated outputs
    echo
    echo -e "${BLUE}📋 Updated Connection Information${NC}"
    echo "=================================="
    aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --query 'Stacks[0].Outputs[].[OutputKey,OutputValue]' \
        --output table
else
    echo -e "${RED}❌ Update failed${NC}"
    exit 1
fi