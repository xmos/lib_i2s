@Library('xmos_jenkins_shared_library@infr_apps_checks') _
// New lib checks fn - will be merged into mainline soon so will need to update this tag

// @Library('xmos_jenkins_shared_library@v0.32.0') _

getApproval()

pipeline {
  agent none

  options {
    skipDefaultCheckout()
    timestamps()
    // on develop discard builds after a certain number else keep forever
    buildDiscarder(logRotator(
        numToKeepStr:         env.BRANCH_NAME ==~ /develop/ ? '25' : '',
        artifactNumToKeepStr: env.BRANCH_NAME ==~ /develop/ ? '25' : ''
    ))
  }

  parameters {
    string(
      name: 'TOOLS_VERSION',
      defaultValue: '15.3.0',
      description: 'The XTC tools version'
    )
  } // parameters

  environment {
    REPO = 'lib_i2s'
    PIP_VERSION = "24.0"
    PYTHON_VERSION = "3.11"
    XMOSDOC_VERSION = "v5.5.2"          
  }

  stages {
    stage("Main") {
      parallel {
        stage('Library Checks and XS2 Tests') {
          agent {
            label 'x86_64&&linux'
          }
          stages {
            stage('Get view') {
              steps {
                sh 'git clone git@github.com:xmos/test_support'
                dir("${REPO}") {
                  checkout scm
                  installPipfile(false)
                  withVenv {
                    withTools(params.TOOLS_VERSION) {
                      sh 'cmake -B build -G "Unix Makefiles"'
                    }
                  }
                }
              }
            }
            stage('Library checks') {
              steps {
                runLibraryChecks("${WORKSPACE}/${REPO}", "lib_checks")
              }
            }
            stage("Build Tests - XS2") {
              steps {
                dir("${REPO}/tests") {
                  withTools(params.TOOLS_VERSION) {
                    sh 'cmake -B build -G "Unix Makefiles"'
                    sh 'xmake -j 20 -C build'
                  // xcoreAllAppNotesBuild('examples')
                  }
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
          stages {
            stage('Get view') {
              steps {
                sh 'git clone git@github.com:xmos/test_support'
                dir("${REPO}") {
                  checkout scm
                  installPipfile(false)
                  withVenv {
                    withTools(params.TOOLS_VERSION) {
                      sh 'cmake -B build -G "Unix Makefiles"'
                    }
                  }
                }
              }
            }
            stage("Build Examples - XS3") {
              steps {
                dir("${REPO}/examples") {
                  withTools(params.TOOLS_VERSION) {
                    sh 'cmake -B build -G "Unix Makefiles"'
                    sh 'xmake -j 20 -C build'
                    // xcoreAllAppNotesBuild('examples')
                  }
                }
              }
            }
            // stage("Test - XS3") {
            //   steps {
            //     dir("${REPO}/tests") {
            //       viewEnv {
            //         // reactivating the tools with the newer version
            //         withTools(params.TOOLS_VERSION) {
            //           runPytest()
            //         }
            //       }
            //     }
            //   }
            // }
            stage('Run xdoc') {
              steps {
                dir("${REPO}") {
                  sh "docker pull ghcr.io/xmos/xmosdoc:$XMOSDOC_VERSION"
                  sh """docker run -u "\$(id -u):\$(id -g)" \
                      --rm \
                      -v \$(pwd):/build \
                      ghcr.io/xmos/xmosdoc:$XMOSDOC_VERSION -v html latex"""

                  // Zip and archive doc files
                  zip dir: "doc/_build/", zipFile: "sw_pll_docs.zip"
                  archiveArtifacts artifacts: "sw_pll_docs.zip"
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
