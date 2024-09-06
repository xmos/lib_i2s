@Library('xmos_jenkins_shared_library@v0.32.0') _

getApproval()

pipeline {
  agent none

  parameters {
    string(
      name: 'TOOLS_VERSION',
      defaultValue: '15.3.0',
      description: 'The XTC tools version'
    )
  } // parameters

  stages {
    stage("Main") {
      parallel {
        stage('Library Checks and XS2 Tests') {
          agent {
            label 'x86_64&&linux'
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
                // git@github.com:xmos/test_support
                
              }
            }
            stage('Library checks') {
              steps {
                xcoreLibraryChecks("${REPO}")
              }
            }
            stage("Build Examples - XS2") {
              steps {
                dir("${REPO}") {
                  xcoreAllAppsBuild('examples')
                  xcoreAllAppNotesBuild('examples')
                }
              }
            }
            stage("Test - XS2") {
              steps {
                dir("${REPO}/tests") {
                  viewEnv {
                    // reactivating the tools with the newer version
                    withTools(params.TOOLS_VERSION) {
                      runPytest()
                    }
                  }
                }
              }
            }
          }
          post {
            cleanup {
              xcoreCleanSandbox()
            }
          }
        } // Library Checks and XS2 Tests
        stage("XS3 Tests and xdoc") {
          agent {
            label 'x86_64&&linux'
          }
          environment {
            REPO = 'lib_i2s'
            VIEW = getViewName(REPO)
            XCORE_AI = 1
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
            stage("Build Examples - XS3") {
              steps {
                dir("${REPO}") {
                  xcoreAllAppsBuild('examples')
                  xcoreAllAppNotesBuild('examples')
                }
              }
            }
            stage("Test - XS3") {
              steps {
                dir("${REPO}/tests") {
                  viewEnv {
                    // reactivating the tools with the newer version
                    withTools(params.TOOLS_VERSION) {
                      runPytest()
                    }
                  }
                }
              }
            }
            stage('Run xdoc') {
              steps {
                dir("${REPO}") {
                  runXdoc('lib_i2s/doc')
                }
              }
            }
          }
          post {
            cleanup {
              xcoreCleanSandbox()
            }
          }
        } // XS3 Tests and xdoc
      } // Parallel
    } // Main
    stage('Update view files') {
      agent {
        label 'x86_64&&linux'
      }
      when {
        expression { return currentBuild.currentResult == "SUCCESS" }
      }
      steps {
        updateViewfiles()
      }
    } // Update view files
  } // stages
} // pipeline
