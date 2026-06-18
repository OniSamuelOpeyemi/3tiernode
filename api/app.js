var express = require('express');
var app = express();
var uuid = require('node-uuid');

var pg = require('pg');
const conString = {
    user: process.env.DBUSER,
    database: process.env.DB,
    password: process.env.DBPASS,
    host: process.env.DBHOST,
    port: process.env.DBPORT,
    ssl: {
        rejectUnauthorized: false    // ← This is important for connecting to Heroku Postgres
    }
};       


// Health check
app.get('/health', function(req, res) {
  res.status(200).json({ status: 'ok' });
});

// Routes
app.get('/api/status', async function(req, res) {
  const { Pool } = require('pg');
  const pool = new Pool(conString);

  try {
    const client = await pool.connect();
    const result = await client.query('SELECT now() AS time');
    client.release();

    const rows = result.rows.map(row => ({
      ...row,
      request_uuid: uuid.v4()
    }));

    return res.status(200).json(rows);
  } catch (err) {
    console.error('Error executing query', err.stack || err);
    return res.status(500).json({ error: 'Database error' });
  } finally {
    await pool.end();
  }
});

// catch 404 and forward to error handler
app.use(function(req, res, next) {
  var err = new Error('Not Found');
  err.status = 404;
  next(err);
});

// error handlers

// development error handler
// will print stacktrace
if (app.get('env') === 'development') {
  app.use(function(err, req, res, next) {
    res.status(err.status || 500);
    res.json({
      message: err.message,
      error: err
    });
  });
}

// production error handler
// no stacktraces leaked to user
app.use(function(err, req, res, next) {
  res.status(err.status || 500);
  res.json({
    message: err.message,
    error: {}
  });
});


module.exports = app;
