FROM node:18

# Install system dependencies for Playwright and GUI forwarding
RUN apt-get update && apt-get install -y \
    # Playwright dependencies
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libatspi2.0-0 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libgbm-dev \
    libgtk-3-0 \
    xdg-utils \
    # GUI forwarding support (lightweight)
    x11-apps \
    x11-utils \
    firefox-esr \
    chromium \
    && rm -rf /var/lib/apt/lists/*

# Set display for GUI forwarding
ENV DISPLAY=:0

WORKDIR /app

COPY package*.json ./

# Handle missing package-lock.json gracefully  
RUN if [ -f package-lock.json ]; then \
      npm ci --omit=dev; \
    else \
      npm install --omit=dev; \
    fi

# Install Playwright and browsers
RUN npx playwright install chromium
RUN npx playwright install-deps

COPY scripts/ ./scripts/
COPY utils/ ./utils/
COPY config/ ./config/
COPY workflows/ ./workflows/

RUN mkdir -p /app/data /app/logs

CMD ["node", "scripts/workflow-engine.js"]
