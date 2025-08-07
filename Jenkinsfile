pipeline {
    agent any
    
    environment {
        // Docker and Registry Configuration
        DOCKER_REGISTRY = 'ghcr.io'
        IMAGE_NAME = 'vpodugu/ecommerce-devops-platform'
        DOCKER_CREDENTIALS = credentials('docker-registry-credentials')
        
        // AWS Configuration
        AWS_REGION = 'us-east-1'
        AWS_CREDENTIALS = credentials('aws-credentials')
        
        // Application Configuration
        APP_NAME = 'ecommerce-microservices'
        ENVIRONMENT = "${params.ENVIRONMENT}"
        
        // Service Images
        USER_SERVICE_IMAGE = "${DOCKER_REGISTRY}/${IMAGE_NAME}/user-service:${BUILD_NUMBER}"
        PRODUCT_SERVICE_IMAGE = "${DOCKER_REGISTRY}/${IMAGE_NAME}/product-service:${BUILD_NUMBER}"
        ORDER_SERVICE_IMAGE = "${DOCKER_REGISTRY}/${IMAGE_NAME}/order-service:${BUILD_NUMBER}"
        API_GATEWAY_IMAGE = "${DOCKER_REGISTRY}/${IMAGE_NAME}/api-gateway:${BUILD_NUMBER}"
        FRONTEND_IMAGE = "${DOCKER_REGISTRY}/${IMAGE_NAME}/frontend:${BUILD_NUMBER}"
    }
    
    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['staging', 'production'],
            description: 'Select deployment environment'
        )
        booleanParam(
            name: 'SKIP_TESTS',
            defaultValue: false,
            description: 'Skip running tests'
        )
        booleanParam(
            name: 'FORCE_DEPLOY',
            defaultValue: false,
            description: 'Force deployment even if tests fail'
        )
    }
    
    options {
        // Build retention
        buildDiscarder(logRotator(numToKeepStr: '10'))
        
        // Timeout
        timeout(time: 1, unit: 'HOURS')
        
        // Disable concurrent builds
        disableConcurrentBuilds()
        
        // Timestamps
        timestamps()
        
        // AnsiColor
        ansiColor('xterm')
    }
    
    stages {
        stage('Checkout') {
            steps {
                script {
                    echo "🚀 Starting E-Commerce Microservices Pipeline"
                    echo "Environment: ${ENVIRONMENT}"
                    echo "Build Number: ${BUILD_NUMBER}"
                }
                
                // Checkout code from Git
                checkout scm
                
                // Set Git commit info
                script {
                    env.GIT_COMMIT = sh(script: 'git rev-parse HEAD', returnStdout: true).trim()
                    env.GIT_BRANCH = sh(script: 'git rev-parse --abbrev-ref HEAD', returnStdout: true).trim()
                    env.GIT_SHORT_COMMIT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                }
            }
        }
        
        stage('Code Quality') {
            parallel {
                stage('Linting') {
                    steps {
                        script {
                            echo "🔍 Running ESLint on all services..."
                            
                            dir('services/user-service') {
                                sh 'npm ci'
                                sh 'npm run lint'
                            }
                            
                            dir('services/product-service') {
                                sh 'npm ci'
                                sh 'npm run lint'
                            }
                            
                            dir('services/order-service') {
                                sh 'npm ci'
                                sh 'npm run lint'
                            }
                            
                            dir('services/api-gateway') {
                                sh 'npm ci'
                                sh 'npm run lint'
                            }
                        }
                    }
                }
                
                stage('Security Scan') {
                    steps {
                        script {
                            echo "🔒 Running security audit..."
                            
                            dir('services/user-service') {
                                sh 'npm audit --audit-level=moderate'
                            }
                            
                            dir('services/product-service') {
                                sh 'npm audit --audit-level=moderate'
                            }
                            
                            dir('services/order-service') {
                                sh 'npm audit --audit-level=moderate'
                            }
                            
                            dir('services/api-gateway') {
                                sh 'npm audit --audit-level=moderate'
                            }
                        }
                    }
                }
            }
        }
        
        stage('Unit Tests') {
            when {
                not { params.SKIP_TESTS }
            }
            steps {
                script {
                    echo "🧪 Running unit tests..."
                    
                    // Start test databases
                    sh 'docker-compose -f docker-compose.test.yml up -d mysql redis'
                    sleep 30
                    
                    dir('services/user-service') {
                        sh 'npm test'
                    }
                    
                    dir('services/product-service') {
                        sh 'npm test'
                    }
                    
                    dir('services/order-service') {
                        sh 'npm test'
                    }
                    
                    dir('services/api-gateway') {
                        sh 'npm test'
                    }
                    
                    // Cleanup test environment
                    sh 'docker-compose -f docker-compose.test.yml down -v'
                }
            }
            post {
                always {
                    // Publish test results
                    publishTestResults testResultsPattern: '**/test-results.xml'
                    
                    // Publish coverage reports
                    publishCoverage adapters: [jacocoAdapter('**/coverage/lcov.info')], 
                                   sourceFileResolver: sourceFiles('STORE_LAST_BUILD')
                }
            }
        }
        
        stage('Integration Tests') {
            when {
                not { params.SKIP_TESTS }
            }
            steps {
                script {
                    echo "🔗 Running integration tests..."
                    
                    // Build and start services for integration testing
                    sh 'docker-compose -f docker-compose.test.yml up -d'
                    sleep 60
                    
                    // Run integration tests
                    sh '''
                        # Test service health endpoints
                        curl -f http://localhost:3001/health || exit 1
                        curl -f http://localhost:3002/health || exit 1
                        curl -f http://localhost:3003/health || exit 1
                        curl -f http://localhost:8080/health || exit 1
                        
                        # Test API endpoints
                        curl -f http://localhost:8080/api/users || exit 1
                        curl -f http://localhost:8080/api/products || exit 1
                        curl -f http://localhost:8080/api/categories || exit 1
                        
                        echo "Integration tests passed!"
                    '''
                }
            }
            post {
                always {
                    sh 'docker-compose -f docker-compose.test.yml down -v'
                }
            }
        }
        
        stage('Build Docker Images') {
            steps {
                script {
                    echo "🐳 Building Docker images..."
                    
                    // Login to Docker registry
                    sh 'echo $DOCKER_CREDENTIALS_PSW | docker login ghcr.io -u $DOCKER_CREDENTIALS_USR --password-stdin'
                    
                    // Build all service images
                    dir('services/user-service') {
                        sh "docker build -t ${USER_SERVICE_IMAGE} ."
                        sh "docker push ${USER_SERVICE_IMAGE}"
                    }
                    
                    dir('services/product-service') {
                        sh "docker build -t ${PRODUCT_SERVICE_IMAGE} ."
                        sh "docker push ${PRODUCT_SERVICE_IMAGE}"
                    }
                    
                    dir('services/order-service') {
                        sh "docker build -t ${ORDER_SERVICE_IMAGE} ."
                        sh "docker push ${ORDER_SERVICE_IMAGE}"
                    }
                    
                    dir('services/api-gateway') {
                        sh "docker build -t ${API_GATEWAY_IMAGE} ."
                        sh "docker push ${API_GATEWAY_IMAGE}"
                    }
                    
                    dir('frontend') {
                        sh "docker build -t ${FRONTEND_IMAGE} ."
                        sh "docker push ${FRONTEND_IMAGE}"
                    }
                }
            }
        }
        
        stage('Deploy to Staging') {
            when {
                expression { params.ENVIRONMENT == 'staging' }
            }
            steps {
                script {
                    echo "🚀 Deploying to staging environment..."
                    
                    // Configure AWS credentials
                    withAWS(credentials: 'aws-credentials', region: 'us-east-1') {
                        // Run Terraform for staging
                        dir('infrastructure/terraform/environments/staging') {
                            sh 'terraform init'
                            sh 'terraform plan -var="environment=staging" -out=tfplan'
                            sh 'terraform apply tfplan'
                        }
                        
                        // Run Ansible deployment
                        dir('infrastructure/ansible') {
                            sh '''
                                ansible-playbook -i inventory/staging.yml playbooks/deploy.yml \
                                    -e "environment=staging" \
                                    -e "user_service_image=${USER_SERVICE_IMAGE}" \
                                    -e "product_service_image=${PRODUCT_SERVICE_IMAGE}" \
                                    -e "order_service_image=${ORDER_SERVICE_IMAGE}" \
                                    -e "api_gateway_image=${API_GATEWAY_IMAGE}" \
                                    -e "frontend_image=${FRONTEND_IMAGE}"
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Staging Tests') {
            when {
                expression { params.ENVIRONMENT == 'staging' }
            }
            steps {
                script {
                    echo "🧪 Running staging tests..."
                    
                    // Get staging URL from Terraform output
                    dir('infrastructure/terraform/environments/staging') {
                        env.STAGING_URL = sh(
                            script: 'terraform output -raw alb_dns_name',
                            returnStdout: true
                        ).trim()
                    }
                    
                    // Run smoke tests
                    sh '''
                        # Test API Gateway
                        curl -f http://${STAGING_URL}/health || exit 1
                        
                        # Test User Service
                        curl -f http://${STAGING_URL}/api/users || exit 1
                        
                        # Test Product Service
                        curl -f http://${STAGING_URL}/api/products || exit 1
                        
                        # Test Order Service
                        curl -f http://${STAGING_URL}/api/orders || exit 1
                        
                        echo "Staging tests passed!"
                    '''
                }
            }
        }
        
        stage('Production Approval') {
            when {
                expression { params.ENVIRONMENT == 'production' }
            }
            steps {
                script {
                    echo "⏳ Waiting for production deployment approval..."
                    
                    // Manual approval step
                    input(
                        message: 'Approve production deployment?',
                        parameters: [
                            string(
                                name: 'APPROVER',
                                defaultValue: '',
                                description: 'Your name for approval tracking'
                            ),
                            text(
                                name: 'REASON',
                                defaultValue: '',
                                description: 'Reason for deployment'
                            )
                        ]
                    )
                    
                    // Record approval
                    env.APPROVER = params.APPROVER
                    env.DEPLOYMENT_REASON = params.REASON
                }
            }
        }
        
        stage('Deploy to Production') {
            when {
                expression { params.ENVIRONMENT == 'production' }
            }
            steps {
                script {
                    echo "🚀 Deploying to production environment..."
                    
                    // Configure AWS credentials
                    withAWS(credentials: 'aws-credentials', region: 'us-east-1') {
                        // Run Terraform for production
                        dir('infrastructure/terraform/environments/production') {
                            sh 'terraform init'
                            sh 'terraform plan -var="environment=production" -out=tfplan'
                            sh 'terraform apply tfplan'
                        }
                        
                        // Run Ansible deployment
                        dir('infrastructure/ansible') {
                            sh '''
                                ansible-playbook -i inventory/production.yml playbooks/deploy.yml \
                                    -e "environment=production" \
                                    -e "user_service_image=${USER_SERVICE_IMAGE}" \
                                    -e "product_service_image=${PRODUCT_SERVICE_IMAGE}" \
                                    -e "order_service_image=${ORDER_SERVICE_IMAGE}" \
                                    -e "api_gateway_image=${API_GATEWAY_IMAGE}" \
                                    -e "frontend_image=${FRONTEND_IMAGE}"
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Production Tests') {
            when {
                expression { params.ENVIRONMENT == 'production' }
            }
            steps {
                script {
                    echo "🧪 Running production tests..."
                    
                    // Get production URL from Terraform output
                    dir('infrastructure/terraform/environments/production') {
                        env.PRODUCTION_URL = sh(
                            script: 'terraform output -raw alb_dns_name',
                            returnStdout: true
                        ).trim()
                    }
                    
                    // Run comprehensive tests
                    sh '''
                        # Test API Gateway
                        curl -f http://${PRODUCTION_URL}/health || exit 1
                        
                        # Test User Service
                        curl -f http://${PRODUCTION_URL}/api/users || exit 1
                        
                        # Test Product Service
                        curl -f http://${PRODUCTION_URL}/api/products || exit 1
                        
                        # Test Order Service
                        curl -f http://${PRODUCTION_URL}/api/orders || exit 1
                        
                        # Performance test
                        ab -n 100 -c 10 http://${PRODUCTION_URL}/api/products
                        
                        echo "Production tests passed!"
                    '''
                }
            }
        }
        
        stage('Performance Tests') {
            when {
                expression { params.ENVIRONMENT == 'production' }
            }
            steps {
                script {
                    echo "⚡ Running performance tests..."
                    
                    // Install Artillery
                    sh 'npm install -g artillery'
                    
                    // Run performance tests
                    sh '''
                        artillery run tests/performance/load-test.yml
                    '''
                }
            }
            post {
                always {
                    // Publish performance test results
                    publishHTML([
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'artillery-report',
                        reportFiles: 'index.html',
                        reportName: 'Performance Test Report'
                    ])
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo "🏁 Pipeline completed with status: ${currentBuild.result}"
                
                // Cleanup Docker images
                sh '''
                    docker rmi ${USER_SERVICE_IMAGE} || true
                    docker rmi ${PRODUCT_SERVICE_IMAGE} || true
                    docker rmi ${ORDER_SERVICE_IMAGE} || true
                    docker rmi ${API_GATEWAY_IMAGE} || true
                    docker rmi ${FRONTEND_IMAGE} || true
                '''
            }
        }
        
        success {
            script {
                echo "✅ Pipeline completed successfully!"
                
                // Send success notification
                if (params.ENVIRONMENT == 'production') {
                    sh '''
                        curl -X POST ${SLACK_WEBHOOK_URL} \
                            -H 'Content-type: application/json' \
                            -d '{
                                "text": "🎉 Production deployment completed successfully!",
                                "attachments": [{
                                    "fields": [
                                        {"title": "Environment", "value": "Production", "short": true},
                                        {"title": "Build", "value": "'${BUILD_NUMBER}'", "short": true},
                                        {"title": "Approver", "value": "'${APPROVER}'", "short": true},
                                        {"title": "URL", "value": "'${PRODUCTION_URL}'", "short": true}
                                    ]
                                }]
                            }'
                    '''
                }
            }
        }
        
        failure {
            script {
                echo "❌ Pipeline failed!"
                
                // Send failure notification
                sh '''
                    curl -X POST ${SLACK_WEBHOOK_URL} \
                        -H 'Content-type: application/json' \
                        -d '{
                            "text": "🚨 Pipeline failed!",
                            "attachments": [{
                                "fields": [
                                    {"title": "Environment", "value": "'${ENVIRONMENT}'", "short": true},
                                    {"title": "Build", "value": "'${BUILD_NUMBER}'", "short": true},
                                    {"title": "Stage", "value": "'${currentBuild.description}'", "short": true}
                                ]
                            }]
                        }'
                '''
            }
        }
        
        cleanup {
            script {
                echo "🧹 Cleaning up workspace..."
                
                // Clean workspace
                cleanWs()
            }
        }
    }
}
