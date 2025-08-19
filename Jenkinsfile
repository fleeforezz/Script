pipeline{
    agent any

    stages{
        stage("Run script"){
            steps{
                echo "========Run Script========"
                dir('Update_apt') {
                    sh './run-script.sh'
                }
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
            to: 'fleeforezz@gmail.com'
        }
    }
}