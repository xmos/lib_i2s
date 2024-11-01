// This file relates to internal XMOS infrastructure and should be ignored by external users

@Library('xmos_jenkins_shared_library@v0.34.0') _

def checkout_shallow()
{
    checkout scm: [
        $class: 'GitSCM',
        branches: scm.branches,
        userRemoteConfigs: scm.userRemoteConfigs,
        extensions: [[$class: 'CloneOption', depth: 1, shallow: true, noTags: false]]
    ]
}

def archiveLib(String repoName) {
    sh "git -C ${repoName} clean -xdf"
    sh "zip ${repoName}_sw.zip -r ${repoName}"
    archiveArtifacts artifacts: "${repoName}_sw.zip", allowEmptyArchive: false
}

getApproval()

pipeline {
    agent none

    options {
        buildDiscarder(xmosDiscardBuildSettings())
        skipDefaultCheckout()
        timestamps()
    }

    parameters {
        string(
            name: 'TOOLS_VERSION',
            defaultValue: '15.3.0',
            description: 'The XTC tools version'
        )
        string(
            name: 'XMOSDOC_VERSION',
            defaultValue: 'v6.1.2',
            description: 'The xmosdoc version'
        )
        string(
            name: 'INFR_APPS_VERSION',
            defaultValue: 'develop',
            description: 'The infr_apps version'
        )
    }

    environment {
        REPO = 'lib_i2s'
        PIP_VERSION = "24.0"
        PYTHON_VERSION = "3.12.1"
    }

    stages {
        stage("Build & test") {
            parallel {
                stage('Library checks & XS2 tests') {
                    agent {
                        label 'x86_64&&linux'
                    }
                    stages {
                        stage('Build examples') {
                            steps {
                                dir("${REPO}") {
                                    checkout_shallow()
                                    withTools(params.TOOLS_VERSION) {
                                        dir("examples") {
                                            // Fetch deps
                                            sh "cmake -G 'Unix Makefiles' -B build -DDEPS_CLONE_SHALLOW=TRUE"
                                            sh 'xmake -C build -j 8'
                                        }
                                    }
                                }
                            }
                        }

                        stage('Library checks') {
                            steps {
                                warnError("Library checks failed") {
                                    runLibraryChecks("${WORKSPACE}/${REPO}", "${params.INFR_APPS_VERSION}")
                                }
                            }
                        }

                        stage("Build tests - XS2") {
                            steps {
                                sh 'git clone git@github.com:xmos/test_support'
                                dir("${REPO}/tests") {
                                    createVenv(reqFile: "requirements.txt")
                                    withVenv {
                                        withTools(params.TOOLS_VERSION) {
                                            sh "cmake -G 'Unix Makefiles' -B build -DDEPS_CLONE_SHALLOW=TRUE"
                                            sh 'xmake -C build -j 8'
                                        }
                                    }
                                }
                            }
                        }

                        stage("Run tests - XS2") {
                            steps {
                                dir("${REPO}/tests") {
                                    withVenv {
                                        withTools(params.TOOLS_VERSION) {
                                            runPytest('--numprocesses=auto -vv')
                                        }
                                    }
                                }
                            }
                        }
                    } // stages
                    post {
                        cleanup {
                            xcoreCleanSandbox()
                        }
                    }
                } // Library checks & XS2 tests

                stage("XS3 build & docs") {
                    agent {
                        label 'x86_64&&linux'
                    }

                    stages {

                        stage("Build Examples - XS3") {
                            steps {
                                dir("${REPO}") {
                                    checkout_shallow()
                                    dir("examples") {
                                        withTools(params.TOOLS_VERSION) {
                                            sh "cmake -G 'Unix Makefiles' -B build -DDEPS_CLONE_SHALLOW=TRUE"
                                            sh 'xmake -j 16 -C build'
                                        }
                                    }
                                }
                            }
                        }

                        stage('Build documentation') {
                            steps {
                                dir("${REPO}") {
                                    warnError("Documentation build failed") {
                                        buildDocs()
                                        dir("examples/AN00162_i2s_loopback_demo") {
                                            buildDocs()
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
                } // XS3 build & docs
            } // Parallel
        } // Build & test
    } // stages
} // pipeline
