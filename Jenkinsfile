pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: sonar-scanner
    image: sonarsource/sonar-scanner-cli
    command: ["cat"]
    tty: true

  - name: kubectl
    image: bitnami/kubectl:latest
    command: ["cat"]
    tty: true
    securityContext:
      runAsUser: 0
    env:
    - name: KUBECONFIG
      value: /kube/config
    volumeMounts:
    - name: kubeconfig-secret
      mountPath: /kube/config
      subPath: kubeconfig

  - name: dind
    image: docker:dind
    securityContext:
      privileged: true
    env:
    - name: DOCKER_TLS_CERTDIR
      value: ""
    args:
    - "--storage-driver=overlay2"
    volumeMounts:
    - name: docker-config
      mountPath: /etc/docker/daemon.json
      subPath: daemon.json
    - name: workspace-volume
      mountPath: /home/jenkins/agent

  - name: jnlp
    image: jenkins/inbound-agent:3309.v27b_9314fd1a_4-1
    env:
    - name: JENKINS_AGENT_WORKDIR
      value: "/home/jenkins/agent"
    volumeMounts:
    - mountPath: "/home/jenkins/agent"
      name: workspace-volume

  volumes:
  - name: workspace-volume
    emptyDir: {}

  - name: docker-config
    configMap:
      name: docker-daemon-config

  - name: kubeconfig-secret
    secret:
      secretName: kubeconfig-secret
'''
        }
    }

    environment {
        NEXUS_REGISTRY = '127.0.0.1:30085'
        REPO_NAME = '2401147-dattaPanchal'
        IMAGE_NAME = 'reactapp'
        NAMESPACE = '2401147'
    }

    stages {

        stage('CHECK') {
            steps {
                echo "DEBUG >>> Updated Jenkinsfile for REACT PROJECT ACTIVE"
            }
        }

        stage('Build React App') {
            steps {
                container('dind') {
                    sh '''
                        echo "Installing Node modules"
                        npm install

                        echo "Building React App"
                        npm run build
                    '''
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                container('dind') {
                    sh '''
                        echo "Waiting for Docker daemon..."
                        for i in $(seq 1 20); do
                            docker info >/dev/null 2>&1 && break
                            echo "dockerd not ready ($i)..."
                            sleep 2
                        done

                        docker build -t reactapp:latest .
                        docker image ls
                    '''
                }
            }
        }

        stage('SonarQube Scan') {
            steps {
                container('sonar-scanner') {
                    withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
                        sh '''
                            sonar-scanner \
                              -Dsonar.projectKey=reactapp \
                              -Dsonar.sources=. \
                              -Dsonar.host.url=http://my-sonarqube-sonarqube.sonarqube.svc.cluster.local:9000 \
                              -Dsonar.login=$SONAR_TOKEN
                        '''
                    }
                }
            }
        }

        stage('Login to Nexus Registry') {
            steps {
                container('dind') {
                    sh '''
                        docker --version
                        sleep 5
                        docker login ${NEXUS_REGISTRY} -u admin -p Changeme@2025
                    '''
                }
            }
        }

        stage('Tag + Push Image') {
            steps {
                container('dind') {
                    sh '''
                        docker tag reactapp:latest ${NEXUS_REGISTRY}/${REPO_NAME}/${IMAGE_NAME}:${BUILD_NUMBER}
                        docker tag reactapp:latest ${NEXUS_REGISTRY}/${REPO_NAME}/${IMAGE_NAME}:latest

                        docker push ${NEXUS_REGISTRY}/${REPO_NAME}/${IMAGE_NAME}:${BUILD_NUMBER}
                        docker push ${NEXUS_REGISTRY}/${REPO_NAME}/${IMAGE_NAME}:latest
                    '''
                }
            }
        }

        stage('Create Namespace + Registry Secret') {
            steps {
                container('kubectl') {
                    sh '''
                        kubectl get namespace ${NAMESPACE} || kubectl create namespace ${NAMESPACE}

                        kubectl create secret docker-registry nexus-secret \
                          --docker-server=${NEXUS_REGISTRY} \
                          --docker-username=admin \
                          --docker-password=Changeme@2025 \
                          --namespace=${NAMESPACE} \
                          --dry-run=client -o yaml | kubectl apply -f -
                    '''
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                container('kubectl') {
                    dir('k8s') {
                        sh '''
                            sed -i "s|reactapp:v1|${NEXUS_REGISTRY}/${REPO_NAME}/${IMAGE_NAME}:${BUILD_NUMBER}|g" deployment.yaml

                            kubectl apply -f deployment.yaml -n ${NAMESPACE}
                            kubectl apply -f service.yaml -n ${NAMESPACE}

                            sleep 5
                            kubectl get pods -n ${NAMESPACE}
                        '''
                    }
                }
            }
        }
    }
}
