# Base image
FROM node:18

# Set working directory
WORKDIR /app

# Copy package files first (better caching)
COPY package*.json ./

# Install system dependencies (VERY IMPORTANT for Strapi)
RUN apt-get update && apt-get install -y \
    build-essential \
    python3 \
    libvips-dev \
    git

# Install Node dependencies
RUN npm install

# Copy project source
COPY . .

# Build Strapi project
RUN npm run build

# Expose Strapi port
EXPOSE 1337

# Start Strapi server
CMD ["npm", "run", "develop"]
