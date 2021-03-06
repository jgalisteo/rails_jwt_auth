require 'rails_helper'

describe RailsJwtAuth::Authenticatable do
  %w(ActiveRecord Mongoid).each do |orm|
    let(:user) { FactoryGirl.create("#{orm.underscore}_user", auth_tokens: %w[abcd]) }

    context "when use #{orm}" do
      describe '#attributes' do
        it { expect(user).to have_attributes(email: user.email) }
        it { expect(user).to have_attributes(password: user.password) }
        it { expect(user).to have_attributes(password: user.password) }
        it { expect(user).to have_attributes(auth_tokens: user.auth_tokens) }
      end

      describe 'validators' do
        it 'validates email' do
          user.email = 'invalid'
          user.valid?
          error = I18n.t('rails_jwt_auth.errors.email.invalid')
          expect(user.errors.messages[:email]).to include(error)
        end
      end

      describe '#authenticate' do
        it 'authenticates user valid password' do
          user = FactoryGirl.create(:active_record_user, password: '12345678')
          expect(user.authenticate('12345678')).not_to eq(false)
          expect(user.authenticate('invalid')).to eq(false)
        end
      end

      describe '#update_with_password' do
        let(:user) { FactoryGirl.create(:active_record_user, password: '12345678') }

        context 'when curren_password is blank' do
          it 'returns false' do
            expect(user.update_with_password(password: 'new_password')).to be_falsey
          end

          it 'addd blank error message' do
            user.update_with_password(password: 'new_password')
            expect(user.errors.messages[:current_password]).to include(
              I18n.t('rails_jwt_auth.errors.current_password.blank')
            )
          end

          it "don't updates password" do
            user.update_with_password(password: 'new_password')
            expect(user.authenticate('new_password')).to be_falsey
          end
        end

        context 'when curren_password is invalid' do
          it 'returns false' do
            expect(user.update_with_password(current_password: 'invalid')).to be_falsey
          end

          it 'addd blank error message' do
            user.update_with_password(current_password: 'invalid')
            expect(user.errors.messages[:current_password]).to include(
              I18n.t('rails_jwt_auth.errors.current_password.invalid')
            )
          end

          it "don't updates password" do
            user.update_with_password(current_password: 'invalid')
            expect(user.authenticate('new_password')).to be_falsey
          end
        end

        context 'when curren_password is valid' do
          it 'returns true' do
            expect(
              user.update_with_password(current_password: '12345678', password: 'new_password')
            ).to be_truthy
          end

          it 'updates password' do
            user.update_with_password(current_password: '12345678', password: 'new_password')
            expect(user.authenticate('new_password')).to be_truthy
          end
        end
      end

      describe '#regenerate_auth_token' do
        context 'when simultaneous_sessions = 1' do
          before do
            RailsJwtAuth.simultaneous_sessions = 1
          end

          it 'creates new authentication token' do
            old_token = user.auth_tokens.first
            user.regenerate_auth_token
            expect(user.auth_tokens.length).to eq(1)
            expect(user.auth_tokens.first).not_to eq(old_token)
          end
        end

        context 'when simultaneous_sessions = 2' do
          before do
            RailsJwtAuth.simultaneous_sessions = 2
          end

          context 'when don\'t pass token' do
            it 'creates new authentication token' do
              old_token = user.auth_tokens.first
              user.regenerate_auth_token
              expect(user.auth_tokens.length).to eq(2)
              expect(user.auth_tokens.first).to eq(old_token)

              new_old_token = user.auth_tokens.last
              user.regenerate_auth_token
              expect(user.auth_tokens.length).to eq(2)
              expect(user.auth_tokens).not_to include(old_token)
              expect(user.auth_tokens.first).to eq(new_old_token)
            end
          end

          context 'when pass token' do
            it 'regeneates this token' do
              old_token = user.auth_tokens.first
              user.regenerate_auth_token old_token
              expect(user.auth_tokens.length).to eq(1)
              expect(user.auth_tokens.first).not_to eq(old_token)
            end
          end
        end
      end

      describe '#destroy_auth_token' do
        before do
          RailsJwtAuth.simultaneous_sessions = 2
        end

        it 'destroy specified token from user auth tokens array' do
          user.regenerate_auth_token
          expect(user.auth_tokens.length).to eq(2)

          token = user.auth_tokens.first
          user.destroy_auth_token token
          expect(user.auth_tokens.length).to eq(1)
          expect(user.auth_tokens.first).not_to eq(token)
        end
      end

      describe '.get_by_token' do
        it 'returns user with specified token' do
          user = FactoryGirl.create(:active_record_user, auth_tokens: %w(abcd efgh))
          expect(user.class.get_by_token('aaaa')).to eq(nil)
          expect(user.class.get_by_token('abcd')).to eq(user)
        end
      end
    end
  end
end
