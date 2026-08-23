pipeline {
    agent any

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

        DEPLOY_SERVER   = 'deploy@15.134.232.121'                // <-- CHANGE (matches SSH credential username/host)
        DEPLOY_SSH_CRED = 'build-server-ssh'                      // Jenkins SSH credential ID from Step 2
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

        stage('Save Docker Image') {
            steps {
                // Export the image to a tarball so it can be transferred without a registry
                sh "docker save ${IMAGE_NAME}:${IMAGE_TAG} -o ${TAR_FILE}"
            }
        }

        stage('Transfer Image to Production') {
            steps {
                withCredentials([string(credentialsId: DEPLOY_HOST_CRED, variable: 'DEPLOY_SERVER')]) {
                    sshagent(credentials: ['deploy-server-ssh-key']) {
                        sh """
                            scp -o StrictHostKeyChecking=no ${TAR_FILE} ${DEPLOY_SERVER}:/tmp/${TAR_FILE}
                        """
                    }
                }
            }
        }

        stage('Deploy on Production') {
            steps {
                withCredentials([string(credentialsId: DEPLOY_HOST_CRED, variable: 'DEPLOY_SERVER')]) {
                    sshagent(credentials: ['deploy-server-ssh-key']) {
                        sh """
                            ssh -o StrictHostKeyChecking=no ${DEPLOY_SERVER} '
                                docker load -i /tmp/${TAR_FILE} &&
                                docker stop ${APP_NAME} || true &&
                                docker rm ${APP_NAME} || true &&
                                docker run -d --name ${APP_NAME} \
                                    -p ${DEPLOY_PORT}:${CONTAINER_PORT} \
                                    --restart unless-stopped \
                                    ${IMAGE_NAME}:${IMAGE_TAG} &&
                                rm -f /tmp/${TAR_FILE}
                            '
                        """
                    }
                }
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
