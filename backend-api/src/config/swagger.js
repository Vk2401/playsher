const path = require('path');
const swaggerJsdoc = require('swagger-jsdoc');

const options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'Playsher API',
      version: '1.0.0',
      description: 'REST API for the Playsher sports booking platform',
      contact: { name: 'Playsher Team' },
    },
    servers: [
      // Relative: Swagger UI resolves it against the host serving the page, so
      // "Try it out" targets this deployment whether local or on Vercel.
      { url: '/api/v1', description: 'This deployment' },
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
        },
      },
      schemas: {
        SuccessResponse: {
          type: 'object',
          properties: {
            success: { type: 'boolean', example: true },
            message: { type: 'string' },
            data: { type: 'object' },
          },
        },
        ErrorResponse: {
          type: 'object',
          properties: {
            success: { type: 'boolean', example: false },
            message: { type: 'string' },
            errors: { type: 'array', items: { type: 'object' } },
          },
        },
        PaginatedResponse: {
          type: 'object',
          properties: {
            success: { type: 'boolean', example: true },
            message: { type: 'string' },
            data: { type: 'array', items: { type: 'object' } },
            pagination: {
              type: 'object',
              properties: {
                total: { type: 'integer' },
                page: { type: 'integer' },
                limit: { type: 'integer' },
                totalPages: { type: 'integer' },
              },
            },
          },
        },
      },
    },
    security: [{ bearerAuth: [] }],
  },
  apis: [path.join(__dirname, '..', 'routes', '*.js')],
};

// Bundlers used by serverless hosts inline the route files, so this glob finds
// nothing there and the spec comes out empty. scripts/generate-swagger.js writes
// the spec at build time; fall back to it whenever the scan yields no paths.
let spec = swaggerJsdoc(options);

if (!spec.paths || Object.keys(spec.paths).length === 0) {
  try {
    spec = { ...require('./swagger.generated.json'), servers: options.definition.servers };
  } catch {
    // No pre-generated spec available — serve whatever the scan produced.
  }
}

module.exports = spec;
