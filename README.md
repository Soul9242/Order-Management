# Real-Time Order Management System

A full-stack Order Management System built with React.js frontend, Spring Boot backend, and AWS services with CI/CD pipeline.

- Frontend: React.js with Material-UI
- Backend: Spring Boot (Java)
- Database: AWS DynamoDB
- File Storage: AWS S3
- Notifications: AWS SNS
- CI/CD: GitHub Actions
- Deployment: AWS Elastic Beanstalk



 1. Clone the Repository
```bash
git clone <repository-url>
cd order-management-system
```

 2. AWS Setup

Create AWS Resources
1. DynamoDB Table
   ```bash
   aws dynamodb create-table \
     --table-name orders \
     --attribute-definitions AttributeName=orderId,AttributeType=S \
     --key-schema AttributeName=orderId,KeyType=HASH \
     --billing-mode PAY_PER_REQUEST
   ```

2. **S3 Bucket**
   ```bash
   aws s3 mb s3://order-management-invoices-<unique-id>
   ```

3. SNS Topic
   ```bash
   aws sns create-topic --name order-notifications
   ```

 Configure AWS Credentials
```bash
aws configure
```

3. Backend Setup

```bash
cd order-service
```

 Environment Variables
Create `application.properties`:
```properties
# AWS Configuration
aws.accessKeyId=your-access-key
aws.secretKey=your-secret-key
aws.region=us-east-1

# DynamoDB
aws.dynamodb.tableName=orders

# S3
aws.s3.bucketName=order-management-invoices-<unique-id>

# SNS
aws.sns.topicArn=arn:aws:sns:us-east-1:123456789012:order-notifications
```

 Run Backend
```bash
mvn spring-boot:run
```

Backend will be available at: http://localhost:8080
Swagger UI: http://localhost:8080/swagger-ui.html

 4. Frontend Setup

```bash
cd order-ui
npm install
npm start
```

Frontend will be available at: http://localhost:3000

 API Reference

 Base URL: `http://localhost:8080`

Create Order
```http
POST /api/orders
Content-Type: multipart/form-data

{
  "customerName": "John Doe",
  "orderAmount": 299.99,
  "invoiceFile": [PDF File]
}
```

 Get Order by ID
```http
GET /api/orders/{orderId}
```

 Get All Orders
```http
GET /api/orders
```

 Swagger Documentation
Visit: http://localhost:8080/swagger-ui.html

Project Structure

```
order-management-system/
├── order-service/          # Spring Boot Backend
│   ├── src/
│   ├── pom.xml
│   └── application.properties
├── order-ui/              # React.js Frontend
│   ├── src/
│   ├── package.json
│   └── public/
├── .github/
│   └── workflows/         # GitHub Actions CI/CD
├── docs/                  # Documentation
└── README.md
```

CI/CD Pipeline

The project includes GitHub Actions workflow that:
1. Builds the Spring Boot application
2. Runs tests
3. Deploys to AWS Elastic Beanstalk
4. Builds and deploys React frontend

Manual Deployment

Backend to AWS Elastic Beanstalk
```bash
cd order-service
mvn clean package
eb init
eb create order-management-backend
eb deploy
```

Frontend to S3 + CloudFront
```bash
cd order-ui
npm run build
aws s3 sync build/ s3://your-frontend-bucket
```

Testing

Backend Tests
```bash
cd order-service
mvn test
```

Frontend Tests
```bash
cd order-ui
npm test
```

Features

-  Real-time order creation and management
-  PDF invoice upload to S3
-  SNS notifications for order events
-  Responsive React.js frontend
-  Swagger API documentation
-  CI/CD pipeline with GitHub Actions
-  AWS DynamoDB integration
-  JWT Authentication (Bonus)
- Order analytics dashboard

 Security

- JWT-based authentication
- AWS IAM roles and policies
- CORS configuration
- Input validation and sanitization

 Monitoring

- AWS CloudWatch logs
- Application metrics
- Error tracking

 License

This project is licensed under the MIT License.

- ✅ Documentation & Code Quality (10%)
- ✅ SNS Email Subscription (5%)
- ✅ Cloud VPS Deployment (10%)
- ✅ Bonus: JWT Authentication
- ✅ Bonus: S3 JSON Export

- ✅ Bonus: Analytics Dashboard 
