process.env.DBUSER = 'postgres';
process.env.DB = 'testdb';
process.env.DBPASS = 'rootpassword';
process.env.DBHOST = '127.0.0.1';
process.env.DBPORT = '5432';

const request = require('supertest');
const chai = require('chai');
const expect = chai.expect;
const pg = require('pg');

class FakePool {
  async connect() {
    return {
      query(_sql) {
        return Promise.resolve({ rows: [{ time: new Date().toISOString(), request_uuid: 'fake-uuid' }] });
      },
      release() {}
    };
  }

  async end() {
    return Promise.resolve();
  }
}

pg.Pool = FakePool;

const app = require('../../app');

describe('API unit tests', function() {
  it('should return status 200 and JSON payload from /api/status', function(done) {
    request(app)
      .get('/api/status')
      .expect('Content-Type', /json/)
      .expect(200)
      .end(function(err, res) {
        if (err) return done(err);
        expect(res.body).to.be.an('array');
        expect(res.body[0]).to.have.property('time');
        expect(res.body[0]).to.have.property('request_uuid');
        done();
      });
  });

  it('should return healthy status on /health', function(done) {
    request(app)
      .get('/health')
      .expect('Content-Type', /json/)
      .expect(200, { status: 'ok' }, done);
  });
});
