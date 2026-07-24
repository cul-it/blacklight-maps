import LeafletController from 'blacklight-maps/controllers/leaflet_controller'

export default class {
  connect() {
    if (typeof Stimulus === "undefined") return
    Stimulus.register('blacklight-maps-leaflet', LeafletController)
  }
}
