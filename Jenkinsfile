// This file relates to internal XMOS infrastructure and should be ignored by external users

@Library('xmos_jenkins_shared_library@v0.34.0') _

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
    PYTHON_VERSION = "3.12.1"
    XMOSDOC_VERSION = "v6.1.2"          
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
                      dir("examples") {
                       // Fetch deps
                       sh 'cmake -B build -G "Unix Makefiles"'
                      }
                    }
                  }
                }
              }
            }
            stage('Library checks') {
              steps {
                runLibraryChecks("${WORKSPACE}/${REPO}", "v2.0.1")
              }
            }
            stage("Build Tests - XS2") {
              steps {
                dir("${REPO}/tests") {
                  withTools(params.TOOLS_VERSION) {
                    sh 'cmake -B build -G "Unix Makefiles"'
                    sh 'xmake -j 16 -C build'
                  }
                }
              }
            }
            stage("Test - XS2") {
              steps {
                dir("${REPO}/tests") {
                  viewEnv {
                    withTools(params.TOOLS_VERSION) {
                      runPytest('--numprocesses=auto -vv')
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
        stage("XS3 Build and docs") {
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
                }
              }
            }
            stage('Run xmosdoc') {
              steps {
                dir("${REPO}") {
                  warnError("Docs") {
                    sh "docker pull ghcr.io/xmos/xmosdoc:$XMOSDOC_VERSION"
                    sh """docker run -u "\$(id -u):\$(id -g)" \
                          --rm \
                          -v \$(pwd):/build \
                          ghcr.io/xmos/xmosdoc:$XMOSDOC_VERSION -v html latex"""

                    // Zip and archive doc files
                    zip dir: "doc/_build/html", zipFile: "lib_i2s_docs_html.zip"
                    archiveArtifacts artifacts: "lib_i2s_docs_html.zip"
                    archiveArtifacts artifacts: "doc/_build/pdf/lib_i2s*.pdf"

                    dir("examples/AN00162_i2s_loopback_demo") {
                      sh """docker run -u "\$(id -u):\$(id -g)" \
                              --rm \
                              -v \$(pwd):/build \
                              ghcr.io/xmos/xmosdoc:$XMOSDOC_VERSION -v html latex"""

                      // Zip and archive doc files
                      zip dir: "doc/_build/html", zipFile: "AN00162_docs_html.zip"
                      archiveArtifacts artifacts: "AN00162_docs_html.zip"
                      archiveArtifacts artifacts: "doc/_build/pdf/AN00162*.pdf"
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
                    sh 'xmake -j 16 -C build'
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
        } // XS3 Build and xdoc
      } // Parallel
    } // Main
  } // stages
} // pipeline
