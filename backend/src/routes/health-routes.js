const router = require('express').Router();
const { health } = require('../controllers/health-controller');
router.get('/', health);
router.get('/setup', require('../controllers/health-controller').setupStatus);
module.exports = router;
