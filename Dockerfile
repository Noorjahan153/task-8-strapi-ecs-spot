FROM node:18

WORKDIR /app

RUN npx create-strapi-app@latest my-app --quickstart

WORKDIR /app/my-app

EXPOSE 1337

CMD ["npm", "run", "develop"]