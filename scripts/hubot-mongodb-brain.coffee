# Description:
#   hubot-mongodb-brain
#   support MongoLab and MongoHQ on heroku.
#
# Dependencies:
#   "mongodb": "*"
#   "lodash" : "*"
#
# Configuration:
#   MONGODB_URL or MONGOLAB_URI or MONGOHQ_URL or 'mongodb://localhost/hubot-brain'
#
# Author:
#   Sho Hashimoto <hashimoto@shokai.org>

'use strict'

_           = require 'lodash'
MongoClient = require('mongodb').MongoClient

deepClone = (obj) -> JSON.parse JSON.stringify obj

module.exports = (robot) ->
  mongoUrl = process.env.MONGODB_URL or
             process.env.MONGOLAB_URI or
             process.env.MONGOHQ_URL or
             'mongodb://localhost/hubot-brain'

  MongoClient.connect mongoUrl, (err, db) ->
    throw err if err

    robot.brain.on 'close', ->
      db.close()

    robot.logger.info "MongoDB connected"
    robot.brain.setAutoSave false

    cache = {}

    ## restore data from mongodb
    db.createCollection 'brain', (err, collection) ->
      robot.logger.debug "Restoring data from brain"
      collection.find().toArray (err, docs) ->
        return robot.logger.error err if err
        data = {}
        for doc in docs
          data[doc._id] = doc.value
        cache = deepClone data
        robot.brain.mergeData data
        robot.brain.resetSaveInterval 10
        robot.brain.setAutoSave true

    ## save data into mongodb
    robot.brain.on 'save', (data) ->
      db.collection 'brain', (err, collection) ->
        for k,v of data
          do (k,v) ->
            return if _.isEqual cache[k], v  # skip not modified key
            robot.logger.debug "saved \"#{k}\" into mongodb-brain"
            cache[k] = deepClone v
            collection.update
              _id:  k
            ,
              $set:
                value: v
            ,
              upsert: true
            , (err, res) ->
              robot.logger.error err if err
            return

