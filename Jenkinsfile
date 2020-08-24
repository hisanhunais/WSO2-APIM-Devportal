pipeline {
    agent any
    environment {
        PROD_ENV = 'production'        
    }
    stages {
        stage('Preparation') {
            steps{
                git branch: "master",
                url: 'https://github.com/HiranyaKavishani/openapi-directory.git'
            }
        }
        stage('Deploy to Production') {
            environment{
                RETRY = '80'
            }
            steps {
                echo 'Logging into $PROD_ENV'
                sh ""
                ./apictl login production -u admin -p admin -k
            }
        }
        stage('Compile Packages') {
            steps {
                sh 'mvn packages'
            }
        }
    }
}