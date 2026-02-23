FROM node:18

WORKDIR /app

COPY strapi/package*.json ./

RUN npm install

COPY strapi ./

RUN npm run build

EXPOSE 1337

CMD ["npm","run","develop"]
