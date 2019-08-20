@Library('xmos_jenkins_shared_library@develop') _

getApproval()

pipeline {
  agent {
    label 'x86_64&&brew'
  }
  environment {
    REPO = 'lib_i2s'
    VIEW = "${env.JOB_NAME.contains('PR-') ? REPO+'_'+env.CHANGE_TARGET : REPO+'_'+env.BRANCH_NAME}"
  }
  triggers {
    /* Trigger this Pipeline on changes to the repos dependencies
     *
     * If this Pipeline is running in a pull request, the triggers are set
     * on the base branch the PR is set to merge in to.
     *
     * Otherwise the triggers are set on the branch of a matching name to the
     * one this Pipeline is on.
     */
    upstream(
      upstreamProjects:
        (env.JOB_NAME.contains('PR-') ?
          "../lib_gpio/${env.CHANGE_TARGET}," +
          "../lib_i2c/${env.CHANGE_TARGET}," +
          "../lib_logging/${env.CHANGE_TARGET}," +
          "../lib_xassert/${env.CHANGE_TARGET}," +
          "../tools_released/${env.CHANGE_TARGET}," +
          "../tools_xmostest/${env.CHANGE_TARGET}," +
          "../xdoc_released/${env.CHANGE_TARGET}"
        :
          "../lib_gpio/${env.BRANCH_NAME}," +
          "../lib_i2c/${env.BRANCH_NAME}," +
          "../lib_logging/${env.BRANCH_NAME}," +
          "../lib_xassert/${env.BRANCH_NAME}," +
          "../tools_released/${env.BRANCH_NAME}," +
          "../tools_xmostest/${env.BRANCH_NAME}," +
          "../xdoc_released/${env.BRANCH_NAME}"),
      threshold: hudson.model.Result.SUCCESS
    )
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
      }
    }
  }
  post {
    success {
      updateViewfiles()
    }
    cleanup {
      cleanWs()
    }
  }
}
