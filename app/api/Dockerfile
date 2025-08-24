FROM node:18-alpine

WORKDIR /app

# Copy manifest first for better layer caching
COPY package*.json ./

# Install production deps
RUN npm install --omit=dev

# Copy app
COPY . .

EXPOSE 8080
CMD ["npm","start"]
