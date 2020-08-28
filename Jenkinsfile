pipeline {
    agent any
    stages {
        stage('Preparation') {
            steps{
                git branch: "master",
                url: 'https://github.com/HiranyaKavishani/openapi-directory.git'
            }
        }
        stage('Deploy to Production') {
            steps {
                sh './import_changes.sh'
            }
        }
    }
}
