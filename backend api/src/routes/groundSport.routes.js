const router = require('express').Router();
const slotRouter = require('./slot.routes');

// Mount slots as nested: /ground-sports/:gsId/slots
router.use('/:gsId/slots', slotRouter);

module.exports = router;
