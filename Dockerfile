# ------------------------------
# Stage 1: Build React App
# ------------------------------
FROM node:18 AS build

WORKDIR /app

# Copy package files
COPY package.json package-lock.json* ./

# Install dependencies
RUN npm install

# Copy all project files
COPY . .

# Build production React app
RUN npm run build


# ------------------------------
# Stage 2: Nginx Server
# ------------------------------
FROM nginx:alpine

# Remove default config
RUN rm -rf /usr/share/nginx/html/*

# Copy React build output to Nginx
COPY --from=build /app/build /usr/share/nginx/html

# Expose port
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
