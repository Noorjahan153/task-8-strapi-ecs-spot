FROM node:18

WORKDIR /app

# Install system dependencies (VERY IMPORTANT for Strapi)
RUN apt-get update && apt-get install -y \
    build-essential \
    python3 \
    libvips-dev

COPY package*.json ./

RUN npm install --legacy-peer-deps

COPY . .

RUN npm run build

EXPOSE 1337

CMD ["npm", "run", "develop"]
