// Action Cable provides the framework to deal with WebSockets in Rails.
// You can generate new channels where WebSocket features live using the rails generate channel command.
let cable;

function setupCable() {
  if (window.booru.userIsSignedIn) {
    cable = ActionCable.createConsumer();
  }
}

export { cable, setupCable };
