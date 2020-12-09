@Library('xmos_jenkins_shared_library@v0.15.1') _

getApproval()

pipeline {
  agent none
  //Tools for AI verif stage. Tools for standard stage in view file
  parameters {
    string(
      name: 'TOOLS_VERSION',
      defaultValue: '15.0.2',
      description: 'The tools version to build with (check /projects/tools/ReleasesTools/)'
      )
    }
    stages {
      stage('Standard build and XS2 tests') {
        agent {
          label 'x86_64&&brew&&macOS'
        }
        environment {
          REPO = 'lib_i2s'
          VIEW = "${env.JOB_NAME.contains('PR-') ? REPO+'_'+env.CHANGE_TARGET : REPO+'_'+env.BRANCH_NAME}"
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
          stage('xCORE builds') {
            steps {
              dir("${REPO}") {
                xcoreAllAppsBuild('examples')
                xcoreAllAppNotesBuild('examples')
                dir("${REPO}") {
                  runXdoc('doc')
                }
              }
            }
          }
          stage('Tests') {
            steps {
              runXmostest("${REPO}", 'tests')
              sh 'tree'
              stash name: 'backpressure_test', includes: 'lib_i2s/tests/backpressure_test/bin/XCORE_AI/backpressure_test_XCORE_AI.xe, '
            }
          }
        }// stages
        post {
          cleanup {
            xcoreCleanSandbox()
          }
        }
      }// Stage standard build

      stage('xcore.ai Verification'){
        agent {
          label 'xcore.ai-explorer'
        }
        environment {
          // '/XMOS/tools' from get_tools.py and rest from tools installers
          TOOLS_PATH = "/XMOS/tools/${params.TOOLS_VERSION}/XMOS/xTIMEcomposer/${params.TOOLS_VERSION}"
        }
        stages{
          stage('Install Dependencies') {
            steps {
              sh '/XMOS/get_tools.py ' + params.TOOLS_VERSION
              installDependencies()
            }
          }
          stage('xrun'){
            steps{
              toolsEnv(TOOLS_PATH) {  // load xmos tools
                //Run this and diff against expected output. Note we have the lib files here available
                // unstash 'debug_printf_test'
                // sh 'xrun --io --id 0 bin/xcoreai/debug_printf_test.xe &> debug_printf_test.txt'
                // sh 'cat debug_printf_test.txt && diff debug_printf_test.txt tests/test.expect'

                //Just run on HW and error on incorrect binary etc. It will not run otherwise due to lack of loopback (intended for sim)
                //We run xsim afterwards for actual test (with loopback)
                unstash 'backpressure_test'
                sh 'xrun --id 0 lib_i2s/tests/backpressure_test/bin/XCORE_AI/backpressure_test_XCORE_AI.xe'
                sh 'xsim --xscope "-offline xscope.xmt" lib_i2s/tests/backpressure_test/bin/XCORE_AI/backpressure_test_XCORE_AI.xe --plugin LoopbackPort.dll "-port tile[0] XS1_PORT_1G 1 0 -port tile[0] XS1_PORT_1A 1 0" > bp_test.txt'
                sh 'cat bp_test.txt && diff bp_test.txt lib_i2s/tests/backpressure_test.expect'
              }
            }
          }
        }//stages
        post {
          cleanup {
            cleanWs()
          }
        }
      }// xcore.ai

    stage('Update view files') {
      agent {
        label 'x86_64&&brew&&macOS'
      }
      when {
        expression { return currentBuild.result == "SUCCESS" }
      }
      steps {
        updateViewfiles()
      }
    }
  }
}
