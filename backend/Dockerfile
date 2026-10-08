FROM ruby:3.3.10-slim

ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=true \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=development:test

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential curl libpq-dev libyaml-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle install
COPY . .

EXPOSE 3000
CMD ["sh", "-c", "bin/rails db:migrate && bin/rails server -b 0.0.0.0 -p 3000"]
