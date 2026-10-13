FROM node:22-alpine
WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev
COPY server.js ./
COPY public ./public
ENV TZ=Europe/Paris PORT=8091 DATA_DIR=/data
VOLUME /data
EXPOSE 8091
CMD ["node", "server.js"]
