pipeline {
    agent {
        label 'build'
    }

    // ---------------------------------------------------------
    // Non-sensitive settings only. Server address, username, and
    // the SSH key all live in Jenkins Credentials (see setup notes
    // below) - nothing identifying is stored in this file.
    // ---------------------------------------------------------
    environment {
        APP_NAME        = 'identity-service'
        IMAGE_NAME      = 'identity-service'
        DEPLOY_PORT     = '8083'
        CONTAINER_PORT  = '8083'
        IMAGE_TAG       = "${env.BUILD_NUMBER}"
        TAR_FILE        = "${APP_NAME}-${env.BUILD_NUMBER}.tar"

        //EPLOY_SERVER   = 'deploy@15.134.232.121'                // <-- CHANGE (matches SSH credential username/host)
        //DEPLOY_HOST_CRED = 'build-server-ssh'                      // Jenkins SSH credential ID from Step 2


        PROD_HOST = '15.134.232.121'
        PROD_USER = 'deploy'
        PROD_DIR = '/opt/project'

    }

    options {
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        stage('Debug Java') {
            steps {
                sh 'echo "PATH=$PATH"'
                sh 'echo "JAVA_HOME=$JAVA_HOME"'
                sh 'which java || echo "java not found on PATH"'
                sh 'java -version'
                sh 'which javac || echo "javac not found on PATH"'
                sh 'javac -version'
            }
        }
        stage('Build') {
            steps {
                sh 'chmod +x mvnw'
                sh './mvnw clean compile -B'
            }
        }

        stage('Test') {
            steps {
                sh './mvnw test -B'
            }
            post {
                always {
                    // Publish JUnit test results even if tests fail
                    junit testResults: 'target/surefire-reports/*.xml', allowEmptyResults: true
                }
            }
        }

        stage('Package') {
            steps {
                sh './mvnw package -DskipTests -B'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh "docker build -t ${IMAGE_NAME}:${IMAGE_TAG} ."
            }
        }

        stage('Deploy') {
            steps {
                echo 'Deploying to production...'

                sh '''
                    docker save ${IMAGE_NAME}:${BUILD_NUMBER} | \
                    gzip > /tmp/${IMAGE_NAME}-${BUILD_NUMBER}.tar.gz

                    scp \
                    -i ~/.ssh/jenkins_deploy_key \
                    -o StrictHostKeyChecking=no \
                    /tmp/${IMAGE_NAME}-${BUILD_NUMBER}.tar.gz \
                    ${PROD_USER}@${PROD_HOST}:${PROD_DIR}/
                '''

                sh '''
                    ssh \
                    -i ~/.ssh/jenkins_deploy_key \
                    -o StrictHostKeyChecking=no \
                    ${PROD_USER}@${PROD_HOST} << EOF

                    cd ${PROD_DIR}

                    gunzip -f ${IMAGE_NAME}-${BUILD_NUMBER}.tar.gz

                    docker load \
                    -i ${IMAGE_NAME}-${BUILD_NUMBER}.tar

                    docker stop ${APP_NAME} || true
                    docker rm ${APP_NAME} || true

                    docker run -d \
                    --name ${APP_NAME} \
                    --restart unless-stopped \
                    -p 80:5000 \
                    ${IMAGE_NAME}:${BUILD_NUMBER}

                    rm -f ${IMAGE_NAME}-${BUILD_NUMBER}.tar

EOF
                '''
            }
        }
    }

    post {
        success {
            echo "Pipeline succeeded: ${APP_NAME} build #${IMAGE_TAG} deployed."
        }
        failure {
            echo "Pipeline failed. Check console output above for details."
        }
        always {
            // Clean up dangling local images and the tarball to save disk space on the build server
            sh "rm -f ${TAR_FILE} || true"
            sh 'docker image prune -f || true'
        }
    }
}
