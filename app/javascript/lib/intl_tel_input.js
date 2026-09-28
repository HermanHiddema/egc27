// intl-tel-input ships a UMD bundle that assigns itself to window.intlTelInput.
// This wrapper re-exports it as an ES module so it can be imported by name.
import "intl-tel-input/umd"

export default window.intlTelInput
