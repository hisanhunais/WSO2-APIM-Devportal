pipeline {
    agent any
    stages {
        stage('Preparation') {
            steps{
                git branch: "master",
                url: 'https://github.com/msm1992/openapi-directory.git'
            }
        }
        stage('Deploy to Production') {
            steps{
                sh './import_changes_modified.sh'
            }
        }
    }
}
