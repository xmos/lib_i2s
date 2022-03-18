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
    stage('Standard build and XS2 tests') {
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
        stage('xCORE builds') {
          steps {
            dir("${REPO}") {
              xcoreAllAppsBuild('examples')
              xcoreAllAppNotesBuild('examples')
              dir('examples/AN00162_i2s_loopback_demo'){
                runXmake(".", "", "XCOREAI=1")
                stash name: 'AN00162', includes: 'bin/XCORE_AI/AN00162_i2s_loopback_demo.xe, '
              }
              dir("${REPO}") {
                runXdoc('doc')
              }
            }
          }
        }
        stage('Tests') {
          steps {
            dir('lib_i2s/tests/backpressure_test'){
              runXmake(".", "", "CONFIG=XCORE_AI")
              stash name: 'backpressure_test', includes: 'bin/XCORE_AI/backpressure_test_XCORE_AI.xe, '
            }
            runXmostest("${REPO}", 'tests')
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
        label 'xcore.ai'
      }
      stages{
        stage('Install Dependencies') {
          steps {
            installDependencies()
          }
        }
        stage('xrun'){
          steps{
            withTools(params.TOOLS_VERSION) {  // load xmos tools
              //Just run on HW and error on incorrect binary etc. We need specific HW for it to run so just check it loads OK
              unstash 'AN00162'
              sh 'xrun --id 0 bin/XCORE_AI/AN00162_i2s_loopback_demo.xe'

              //Just run on HW and error on incorrect binary etc. It will not run otherwise due to lack of loopback (intended for sim)
              //We run xsim afterwards for actual test (with loopback)
              unstash 'backpressure_test'
              sh 'xrun --id 0 bin/XCORE_AI/backpressure_test_XCORE_AI.xe'
              sh 'xsim bin/XCORE_AI/backpressure_test_XCORE_AI.xe --plugin LoopbackPort.dll "-port tile[0] XS1_PORT_1G 1 0 -port tile[0] XS1_PORT_1A 1 0" > bp_test.txt'
              sh 'cat bp_test.txt && diff bp_test.txt tests/backpressure_test.expect'
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
