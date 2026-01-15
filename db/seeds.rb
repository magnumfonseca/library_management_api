# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "🌱 Seeding database..."

# Clear existing data in development
if Rails.env.development?
  puts "Clearing existing data..."
  Borrowing.destroy_all
  Book.destroy_all
  User.destroy_all
end

# Create Librarians
puts "Creating librarians..."
librarian1 = User.create!(
  name: "Alice Johnson",
  email: "alice.johnson@library.com",
  password: "password123",
  password_confirmation: "password123",
  role: :librarian
)

librarian2 = User.create!(
  name: "Bob Smith",
  email: "bob.smith@library.com",
  password: "password123",
  password_confirmation: "password123",
  role: :librarian
)

puts "Created #{User.where(role: :librarian).count} librarians"

# Create Members
puts "Creating members..."
member1 = User.create!(
  name: "Charlie Brown",
  email: "charlie.brown@email.com",
  password: "password123",
  password_confirmation: "password123",
  role: :member
)

member2 = User.create!(
  name: "Diana Prince",
  email: "diana.prince@email.com",
  password: "password123",
  password_confirmation: "password123",
  role: :member
)

member3 = User.create!(
  name: "Ethan Hunt",
  email: "ethan.hunt@email.com",
  password: "password123",
  password_confirmation: "password123",
  role: :member
)

member4 = User.create!(
  name: "Fiona Green",
  email: "fiona.green@email.com",
  password: "password123",
  password_confirmation: "password123",
  role: :member
)

member5 = User.create!(
  name: "George Miller",
  email: "george.miller@email.com",
  password: "password123",
  password_confirmation: "password123",
  role: :member
)

puts "Created #{User.where(role: :member).count} members"

# Create Books
puts "Creating books..."

books_data = [
  { title: "The Great Gatsby", author: "F. Scott Fitzgerald", genre: "Classic Fiction", isbn: "9780743273565", total_copies: 5 },
  { title: "To Kill a Mockingbird", author: "Harper Lee", genre: "Classic Fiction", isbn: "9780061120084", total_copies: 4 },
  { title: "1984", author: "George Orwell", genre: "Science Fiction", isbn: "9780451524935", total_copies: 6 },
  { title: "Pride and Prejudice", author: "Jane Austen", genre: "Romance", isbn: "9780141439518", total_copies: 3 },
  { title: "The Hobbit", author: "J.R.R. Tolkien", genre: "Fantasy", isbn: "9780547928227", total_copies: 7 },
  { title: "Harry Potter and the Sorcerer's Stone", author: "J.K. Rowling", genre: "Fantasy", isbn: "9780590353427", total_copies: 8 },
  { title: "The Catcher in the Rye", author: "J.D. Salinger", genre: "Classic Fiction", isbn: "9780316769174", total_copies: 4 },
  { title: "The Lord of the Rings", author: "J.R.R. Tolkien", genre: "Fantasy", isbn: "9780544003415", total_copies: 5 },
  { title: "Animal Farm", author: "George Orwell", genre: "Political Satire", isbn: "9780451526342", total_copies: 6 },
  { title: "Brave New World", author: "Aldous Huxley", genre: "Science Fiction", isbn: "9780060850524", total_copies: 4 },
  { title: "The Da Vinci Code", author: "Dan Brown", genre: "Mystery", isbn: "9780307474278", total_copies: 5 },
  { title: "The Alchemist", author: "Paulo Coelho", genre: "Fiction", isbn: "9780062315007", total_copies: 6 },
  { title: "The Book Thief", author: "Markus Zusak", genre: "Historical Fiction", isbn: "9780375842207", total_copies: 3 },
  { title: "The Hunger Games", author: "Suzanne Collins", genre: "Science Fiction", isbn: "9780439023528", total_copies: 7 },
  { title: "The Chronicles of Narnia", author: "C.S. Lewis", genre: "Fantasy", isbn: "9780066238500", total_copies: 5 },
  { title: "Sapiens", author: "Yuval Noah Harari", genre: "Non-Fiction", isbn: "9780062316097", total_copies: 4 },
  { title: "Educated", author: "Tara Westover", genre: "Memoir", isbn: "9780399590504", total_copies: 3 },
  { title: "Becoming", author: "Michelle Obama", genre: "Biography", isbn: "9781524763138", total_copies: 5 },
  { title: "The Silent Patient", author: "Alex Michaelides", genre: "Thriller", isbn: "9781250301697", total_copies: 4 },
  { title: "Where the Crawdads Sing", author: "Delia Owens", genre: "Fiction", isbn: "9780735219090", total_copies: 6 }
]

books = books_data.map do |book_data|
  Book.create!(book_data)
end

puts "Created #{Book.count} books"

# Create Borrowings
puts "Creating borrowings..."

# Active borrowings
active_borrowings = [
  { user: member1, book: books[0], borrowed_at: 10.days.ago, due_date: 4.days.from_now },
  { user: member1, book: books[5], borrowed_at: 5.days.ago, due_date: 9.days.from_now },
  { user: member2, book: books[2], borrowed_at: 12.days.ago, due_date: 2.days.from_now },
  { user: member3, book: books[4], borrowed_at: 8.days.ago, due_date: 6.days.from_now },
  { user: member3, book: books[10], borrowed_at: 3.days.ago, due_date: 11.days.from_now },
  { user: member4, book: books[7], borrowed_at: 14.days.ago, due_date: Time.current }, # Due today
  { user: member5, book: books[15], borrowed_at: 6.days.ago, due_date: 8.days.from_now }
]

active_borrowings.each do |borrowing_data|
  Borrowing.create!(borrowing_data)
end

# Overdue borrowings
overdue_borrowings = [
  { user: member2, book: books[1], borrowed_at: 20.days.ago, due_date: 6.days.ago },
  { user: member4, book: books[3], borrowed_at: 25.days.ago, due_date: 11.days.ago }
]

overdue_borrowings.each do |borrowing_data|
  Borrowing.create!(borrowing_data)
end

# Returned borrowings
returned_borrowings = [
  { user: member1, book: books[6], borrowed_at: 30.days.ago, due_date: 16.days.ago, returned_at: 15.days.ago },
  { user: member2, book: books[8], borrowed_at: 35.days.ago, due_date: 21.days.ago, returned_at: 20.days.ago },
  { user: member3, book: books[9], borrowed_at: 40.days.ago, due_date: 26.days.ago, returned_at: 25.days.ago },
  { user: member4, book: books[11], borrowed_at: 45.days.ago, due_date: 31.days.ago, returned_at: 28.days.ago },
  { user: member5, book: books[12], borrowed_at: 50.days.ago, due_date: 36.days.ago, returned_at: 35.days.ago },
  { user: member1, book: books[13], borrowed_at: 55.days.ago, due_date: 41.days.ago, returned_at: 40.days.ago },
  { user: member2, book: books[14], borrowed_at: 60.days.ago, due_date: 46.days.ago, returned_at: 44.days.ago }
]

returned_borrowings.each do |borrowing_data|
  Borrowing.create!(borrowing_data)
end

puts "Created #{Borrowing.count} borrowings:"
puts "  - Active: #{Borrowing.active.count}"
puts "  - Overdue: #{Borrowing.overdue.count}"
puts "  - Returned: #{Borrowing.returned.count}"

puts "\n✅ Database seeded successfully!"
puts "\n📊 Summary:"
puts "  - Librarians: #{User.where(role: :librarian).count}"
puts "  - Members: #{User.where(role: :member).count}"
puts "  - Books: #{Book.count}"
puts "  - Total Borrowings: #{Borrowing.count}"
puts "\n🔐 Default password for all users: password123"
