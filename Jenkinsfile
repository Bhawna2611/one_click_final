pipeline {
    agent any
    
    parameters {
        // This allows you to choose apply or destroy at the start of the build
        choice(name: 'TF_ACTION', choices: ['apply', 'destroy'], description: 'Select the Terraform action to perform')
    }

    environment {
        TF_DIRECTORY = 'terraform'
        ANSIBLE_DIRECTORY = 'ansible'
        AWS_DEFAULT_REGION = 'us-east-1'
        AWS_CREDS = credentials('aws-keys')

        LANG = 'en_US.UTF-8'
        LC_ALL = 'en_US.UTF-8'
    }

    stages {
        stage('Clean Workspace') {
            steps {
                cleanWs()
            }
        }

        stage('Checkout Source') {
            steps {
                checkout scm
            }
        }

        stage('Terraform Infrastructure') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'aws-keys', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY'), sshUserPrivateKey(credentialsId: 'my-server-ssh-key-v1', keyFileVariable: 'SSH_KEY')]) {
                    script {
                        // Copy SSH key for Terraform provisioners to use
                        sh 'rm -f /tmp/one__click.pem && cp "$SSH_KEY" /tmp/one__click.pem && chmod 400 /tmp/one__click.pem'

                        // Read key content and expose as TF_VAR so Terraform receives it directly
                        // This avoids using file() which cannot read from /tmp in newer Terraform versions
                        env.TF_VAR_ssh_private_key = sh(script: 'cat /tmp/one__click.pem', returnStdout: true).trim()

                        dir("${env.TF_DIRECTORY}") {
                            sh 'terraform init -input=false -migrate-state -force-copy'

                            if (params.TF_ACTION == 'apply') {
                                // Untaint any resources tainted from previous failed runs to avoid "already exists" errors
                                sh '''
                                    for resource in $(terraform state list 2>/dev/null); do
                                        if terraform state show "$resource" 2>/dev/null | grep -q "^  # .* (tainted)"; then
                                            echo "Untainting: $resource"
                                            terraform untaint "$resource" || true
                                        fi
                                    done
                                    echo "Taint check complete."
                                '''
                                sh 'terraform apply -auto-approve -input=false'
                            } else {
                                sh 'terraform destroy -auto-approve -input=false'
                            }
                        }
                    }
                }
            }
        }

        stage('Update Inventory') {
            when { expression { params.TF_ACTION == 'apply' } }
            steps {
                script {
                    // Terraform already generates inventory.ini via local_file + templatefile
                    // Just verify it was created correctly
                    dir("${env.ANSIBLE_DIRECTORY}") {
                        sh 'echo "=== Generated Inventory ===" && cat inventory.ini'
                    }
                }
            }
        }

        stage('Ansible Lint') {
            when { expression { params.TF_ACTION == 'apply' } }
            steps {
                dir("${env.ANSIBLE_DIRECTORY}") {
                    sh 'ansible-lint -v playbook.yml || true'
                }
            }
        }

        stage('Ansible Setup & Install Docker') {
            when { expression { params.TF_ACTION == 'apply' } }
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: 'my-server-ssh-key-v1', keyFileVariable: 'SSH_KEY')]) {
                    dir("${env.ANSIBLE_DIRECTORY}") {
                        // Wait for ASG instances to be fully up and user_data to complete
                        sh 'echo "Waiting 120s for ASG instances and user_data to complete..." && sleep 120'
                        // Copy SSH key
                        sh "rm -f /tmp/one__click.pem && cp ${SSH_KEY} /tmp/one__click.pem && chmod 400 /tmp/one__click.pem"
                        // Run Ansible with retries
                        sh "ansible-playbook -i inventory.ini playbook.yml --private-key=/tmp/one__click.pem -u ubuntu"
                    }
                }
            }
        }

        stage('Docker setup & install MySQL') {
            when { expression { params.TF_ACTION == 'apply' } }
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: 'my-server-ssh-key-v1', keyFileVariable: 'SSH_KEY')]) {
                    dir("${env.ANSIBLE_DIRECTORY}") {
                        // Copy entire docker folder to remote server (as root so dest dir can be created)
                        sh "ansible all -i inventory.ini -m copy -a 'src=../docker/ dest=/home/ubuntu/employee-app/' --become --private-key=/tmp/one__click.pem -u ubuntu"

                        // Deploy using docker-compose
                        sh """
                            ansible all -i inventory.ini -m shell -a '
                                cd /home/ubuntu/employee-app && \\
                                sudo docker-compose down || true && \\
                                sudo docker-compose up -d --build && \\
                                echo "Waiting 30s for MySQL and app to be ready..." && \\
                                sleep 30 && \\
                                sudo docker-compose ps
                            ' --become --private-key=/tmp/one__click.pem -u ubuntu
                        """

                        // Verify deployment (use || true so status is shown without failing pipeline)
                        sh """
                            ansible all -i inventory.ini -m shell -a '
                                echo "=== Container Status ===" && \\
                                sudo docker-compose -f /home/ubuntu/employee-app/docker-compose.yml ps && \\
                                echo "=== Checking Frontend ===" && \\
                                curl -s -o /dev/null -w "Frontend HTTP Status: %{http_code}\\n" http://localhost:3000 || echo "Frontend not responding yet" && \\
                                echo "=== Checking API ===" && \\
                                curl -s http://localhost:3000/api/employees | head -c 200 || echo "API not responding yet"
                            ' --become --private-key=/tmp/one__click.pem -u ubuntu
                        """
                    }
                }
            }
        }

    }

    post { 
        always { 
            // Cleanup sensitive files from the Jenkins agent
            sh 'rm -f /tmp/one__click.pem' 
        }
        success {
           // Send Email notification on Success
            mail to: 'bhavna123porwal@gmail.com',
                 from: 'bhavna123porwal@gmail.com',
                 subject: "Success: ${env.JOB_NAME} Build #${env.BUILD_NUMBER}",
                 body: "Check details at ${env.BUILD_URL}"
        }

        failure {

            // Send Email notification on Failure
            mail to: 'bhavna123porwal@gmail.com',
                 from: 'bhavna123porwal@gmail.com',
                 subject: "FAILURE: ${env.JOB_NAME} Build #${env.BUILD_NUMBER}",
                 body: "The build failed. Please check the logs at ${env.BUILD_URL}"
        }

    }
}
