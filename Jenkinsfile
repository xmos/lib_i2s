@Library('xmos_jenkins_shared_library@v0.18.0') _

getApproval()

pipeline {
  agent none
  //Tools for AI verif stage. Tools for standard stage in view file
  parameters {
    string(
      name: 'TOOLS_VERSION',
      defaultValue: '15.1.4',
      description: 'The tools version to build with (check /projects/tools/ReleasesTools/)'
      )
  }
  stages {
    stage('Library Checks, Build, and Test') {
      agent {
        label 'x86_64&&macOS'
      }
      environment {
        REPO = 'lib_i2s'
        VIEW = getViewName(REPO)
      }
      options {
        skipDefaultCheckout()
      }
      stages {
        stage('Get view') {
          steps {
            xcorePrepareSandbox("${VIEW}", "${REPO}")
          }
        }
        stage('Library checks') {
          steps {
            xcoreLibraryChecks("${REPO}")
          }
        }
        stage('Build and Test - XS2 and XS3') {
          parallel {
            stage("Build and Test - XS2"){
              steps{
                dir("${REPO}") {
                  xcoreAllAppsBuild('examples')
                  xcoreAllAppNotesBuild('examples')
                }
                dir("${REPO}") {
                  viewEnv {
                    runPytest()
                  }
                }
              }
            }
            stage("Build and Test - XS3"){
              environment {
                XCORE_AI = 1
              }
              steps{
                dir("${REPO}") {
                  xcoreAllAppsBuild('examples')
                  xcoreAllAppNotesBuild('examples')
                }
                dir("${REPO}") {
                  viewEnv {
                    runPytest()
                  }
                }
              }
            }
          }
        }
        stage('Run xdoc'){
          steps{
            dir("${REPO}") {
              runXdoc('doc')
            }
          }
        }
      }// stages
      post {
        cleanup {
          xcoreCleanSandbox()
        }
      }
    }// Stage standard build
    stage('Update view files') {
      agent {
        label 'x86_64&&macOS'
      }
      when {
        expression { return currentBuild.currentResult == "SUCCESS" }
      }
      steps {
        updateViewfiles()
      }
    }
  }
}
