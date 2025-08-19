pipeline{
    agent{
        label "any"
    }
    stages{
        stage("Run script"){
            steps{
                echo "========Run Script========"
                sh "bash ./Update_apt/run-script.sh"
            }
        }
    }
    post{
        always{
            emailext attachLog: true, 
            subject: "${currentBuild.result}",
            body: "Project: ${env.JOB_NAME}<br/>" +
            "Build Number: ${env.BUILD_NUMBER}<br/>" +
            "URL: ${env.BUILD_URL}<br/>",
            to: 'fleeforezz@gmail.com',
        }
    }
}