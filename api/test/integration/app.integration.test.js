process.env.DBUSER = 'postgres';
process.env.DB = 'testdb';
process.env.DBPASS = 'rootpassword';
process.env.DBHOST = '127.0.0.1';
process.env.DBPORT = '5432';

const request = require('supertest');
const chai = require('chai');
const expect = chai.expect;
const app = require('../../app');

describe('API integration tests', function() {
  it('should return a JSON array from /api/status when PostgreSQL is available', function(done) {
    if (!process.env.CI) {
      this.skip();
    }

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
});
