process.env.API_HOST = 'http://localhost:4000';

const nock = require('nock');
const request = require('supertest');
const chai = require('chai');
const expect = chai.expect;
const app = require('../../app');

describe('Web unit tests', function() {
  beforeEach(function() {
    nock.cleanAll();
  });

  it('should render the home page when the API status endpoint succeeds', function(done) {
    nock('http://localhost:4000')
      .get('/api/status')
      .reply(200, [{ request_uuid: 'abc123', time: '2026-06-09T00:00:00.000Z' }]);

    request(app)
      .get('/')
      .expect(200)
      .end(function(err, res) {
        if (err) return done(err);
        expect(res.text).to.include('3tier App');
        expect(res.text).to.include('abc123');
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
