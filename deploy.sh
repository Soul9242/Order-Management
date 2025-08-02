#!/bin/bash

# Order Management System Deployment Script
# This script automates the deployment of the Order Management System

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="order-management-system"
AWS_REGION="us-east-1"
DYNAMODB_TABLE="orders"
S3_BUCKET_PREFIX="order-management-invoices"
SNS_TOPIC_NAME="order-notifications"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    local missing_tools=()
    
    if ! command_exists java; then
        missing_tools+=("Java 17")
    fi
    
    if ! command_exists mvn; then
        missing_tools+=("Maven")
    fi
    
    if ! command_exists node; then
        missing_tools+=("Node.js")
    fi
    
    if ! command_exists npm; then
        missing_tools+=("npm")
    fi
    
    if ! command_exists aws; then
        missing_tools+=("AWS CLI")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_status "Please install the missing tools and try again."
        exit 1
    fi
    
    print_success "All prerequisites are installed"
}

# Function to setup AWS resources
setup_aws_resources() {
    print_status "Setting up AWS resources..."
    
    # Create DynamoDB table
    print_status "Creating DynamoDB table..."
    aws dynamodb create-table \
        --table-name $DYNAMODB_TABLE \
        --attribute-definitions AttributeName=orderId,AttributeType=S \
        --key-schema AttributeName=orderId,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region $AWS_REGION > /dev/null 2>&1 || print_warning "DynamoDB table might already exist"
    
    # Create S3 bucket
    local timestamp=$(date +%s)
    local s3_bucket="${S3_BUCKET_PREFIX}-${timestamp}"
    print_status "Creating S3 bucket: $s3_bucket"
    aws s3 mb s3://$s3_bucket --region $AWS_REGION > /dev/null 2>&1
    
    # Configure S3 bucket for static website hosting
    aws s3api put-bucket-cors --bucket $s3_bucket --cors-configuration '{
        "CORSRules": [
            {
                "AllowedHeaders": ["*"],
                "AllowedMethods": ["GET", "PUT", "POST", "DELETE"],
                "AllowedOrigins": ["*"],
                "ExposeHeaders": []
            }
        ]
    }' > /dev/null 2>&1
    
    # Create SNS topic
    print_status "Creating SNS topic..."
    local topic_arn=$(aws sns create-topic --name $SNS_TOPIC_NAME --region $AWS_REGION --query 'TopicArn' --output text)
    
    print_success "AWS resources created successfully"
    echo "S3_BUCKET_NAME=$s3_bucket" > .env.aws
    echo "SNS_TOPIC_ARN=$topic_arn" >> .env.aws
}

# Function to build backend
build_backend() {
    print_status "Building Spring Boot backend..."
    
    cd order-service
    
    # Clean and build
    mvn clean package -DskipTests
    
    if [ $? -eq 0 ]; then
        print_success "Backend built successfully"
    else
        print_error "Backend build failed"
        exit 1
    fi
    
    cd ..
}

# Function to build frontend
build_frontend() {
    print_status "Building React frontend..."
    
    cd order-ui
    
    # Install dependencies
    npm install
    
    # Build for production
    npm run build
    
    if [ $? -eq 0 ]; then
        print_success "Frontend built successfully"
    else
        print_error "Frontend build failed"
        exit 1
    fi
    
    cd ..
}

# Function to run tests
run_tests() {
    print_status "Running tests..."
    
    # Backend tests
    cd order-service
    mvn test
    cd ..
    
    # Frontend tests
    cd order-ui
    npm test -- --watchAll=false --coverage
    cd ..
    
    print_success "All tests passed"
}

# Function to start services locally
start_local_services() {
    print_status "Starting services locally..."
    
    # Start backend
    cd order-service
    print_status "Starting Spring Boot backend on port 8080..."
    mvn spring-boot:run > ../backend.log 2>&1 &
    local backend_pid=$!
    cd ..
    
    # Wait for backend to start
    sleep 10
    
    # Start frontend
    cd order-ui
    print_status "Starting React frontend on port 3000..."
    npm start > ../frontend.log 2>&1 &
    local frontend_pid=$!
    cd ..
    
    # Save PIDs for cleanup
    echo $backend_pid > .backend.pid
    echo $frontend_pid > .frontend.pid
    
    print_success "Services started locally"
    print_status "Backend: http://localhost:8080"
    print_status "Frontend: http://localhost:3000"
    print_status "Swagger UI: http://localhost:8080/swagger-ui.html"
}

# Function to stop local services
stop_local_services() {
    print_status "Stopping local services..."
    
    
    if [ -f .backend.pid ]; then
        kill $(cat .backend.pid) 2>/dev/null || true
        rm .backend.pid
    fi
    
    if [ -f .frontend.pid ]; then
        kill $(cat .frontend.pid) 2>/dev/null || true
        rm .frontend.pid
    fi
    
    print_success "Local services stopped"
}

# Function to deploy to AWS
deploy_to_aws() {
    print_status "Deploying to AWS..."
    
    # Check if EB CLI is installed
    if ! command_exists eb; then
        print_status "Installing EB CLI..."
        pip install awsebcli
    fi
    
    # Initialize EB application
    cd order-service
    eb init $PROJECT_NAME --platform java --region $AWS_REGION --non-interactive || true
    
    # Create environment
    eb create order-management-backend \
        --instance-type t3.micro \
        --single-instance \
        --envvars \
            AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID,\
            AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY,\
            AWS_REGION=$AWS_REGION,\
            DYNAMODB_TABLE_NAME=$DYNAMODB_TABLE,\
            S3_BUCKET_NAME=$(grep S3_BUCKET_NAME ../.env.aws | cut -d'=' -f2),\
            SNS_TOPIC_ARN=$(grep SNS_TOPIC_ARN ../.env.aws | cut -d'=' -f2) || true
    
    cd ..
    
    # Deploy frontend to S3
    local s3_bucket=$(grep S3_BUCKET_NAME .env.aws | cut -d'=' -f2)
    aws s3 sync order-ui/build/ s3://$s3_bucket --delete
    
    print_success "Deployment completed"
    print_status "Backend: https://order-management-backend.$AWS_REGION.elasticbeanstalk.com"
    print_status "Frontend: https://$s3_bucket.s3-website-$AWS_REGION.amazonaws.com"
}

# Function to cleanup
cleanup() {
    print_status "Cleaning up..."
    
    stop_local_services
    
    # Remove log files
    rm -f backend.log frontend.log
    
    print_success "Cleanup completed"
}

# Function to show help
show_help() {
    echo "Order Management System Deployment Script"
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  setup       Setup AWS resources (DynamoDB, S3, SNS)"
    echo "  build       Build both backend and frontend"
    echo "  test        Run all tests"
    echo "  start       Start services locally"
    echo "  stop        Stop local services"
    echo "  deploy      Deploy to AWS"
    echo "  clean       Clean up local resources"
    echo "  all         Run complete setup and deployment"
    echo "  help        Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  AWS_ACCESS_KEY_ID     AWS access key"
    echo "  AWS_SECRET_ACCESS_KEY AWS secret key"
    echo "  AWS_REGION            AWS region (default: us-east-1)"
}

# Main script logic
case "${1:-help}" in
    "setup")
        check_prerequisites
        setup_aws_resources
        ;;
    "build")
        check_prerequisites
        build_backend
        build_frontend
        ;;
    "test")
        check_prerequisites
        run_tests
        ;;
    "start")
        check_prerequisites
        start_local_services
        ;;
    "stop")
        stop_local_services
        ;;
    "deploy")
        check_prerequisites
        if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
            print_error "AWS credentials not set. Please set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY"
            exit 1
        fi
        deploy_to_aws
        ;;
    "clean")
        cleanup
        ;;
    "all")
        check_prerequisites
        setup_aws_resources
        build_backend
        build_frontend
        run_tests
        start_local_services
        print_status "Complete setup finished. Services are running locally."
        print_status "To deploy to AWS, run: $0 deploy"
        ;;
    "help"|*)
        show_help
        ;;
esac 