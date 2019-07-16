import '@babel/polyfill'
import 'core-js/es7/object'

import {SignupPageWrapper} from 'LoginPage'
import {safeFromJsonString} from 'utilities/json-utils'
import {isBrowserIE11} from 'utilities/ie11Utils'

const isIE11 = isBrowserIE11(window)
if (isIE11) {
  import('LoginPage/assets/styles/ie11-pf4BaseStyles.css')
}

document.addEventListener('DOMContentLoaded', () => {
  const PFLoginPageContainer = document.getElementById('pf-login-page-container')
  if (isIE11) {
    PFLoginPageContainer.classList.add('isIe11', 'pf-c-page')
  }

  let oldLoginWrapper = document.getElementById('old-login-page-wrapper')
  if (oldLoginWrapper.parentNode) {
    oldLoginWrapper.parentNode.removeChild(oldLoginWrapper)
  }

  const signupPageProps = safeFromJsonString(PFLoginPageContainer.dataset.signupProps)
  SignupPageWrapper(signupPageProps, 'pf-login-page-container')
})
