defmodule PhilomenaWeb.Image.CommentController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.MarkdownRenderer
  alias PhilomenaWeb.RateLimitedResponse
  alias Philomena.Comments

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, %{"comment_id" => comment_id, "image_id" => image_id}) do
    with {:ok, {image, page}} <-
           Comments.list_comment_page(
             conn.assigns.actor,
             image_id,
             comment_id,
             conn.assigns.comment_scrivener
           ) do
      redirect(conn, to: ~p"/images/#{image}/comments?#{[page: page]}")
    end
  end

  def index(conn, %{"image_id" => image_id}) do
    with {:ok, image} <- Comments.load_image(conn.assigns.actor, image_id, :index) do
      comments =
        Comments.list_image_comments(
          conn.assigns.actor,
          image,
          conn.assigns.comment_scrivener
        )

      rendered = MarkdownRenderer.render_collection(comments.entries, conn)

      comments = %{comments | entries: Enum.zip(comments.entries, rendered)}

      render(conn, "index.html", layout: false, image: image, comments: comments)
    end
  end

  def show(conn, %{"id" => comment_id, "image_id" => image_id}) do
    with {:ok, {image, comment}} <-
           Comments.show_comment(conn.assigns.actor, image_id, comment_id) do
      rendered = MarkdownRenderer.render_one(comment, conn)

      render(conn, "show.html",
        layout: false,
        image: image,
        comment: comment,
        body: rendered
      )
    end
  end

  def create(conn, %{"comment" => comment_params, "image_id" => image_id}) do
    case Comments.create_comment(conn.assigns.actor, image_id, comment_params) do
      {:ok, comment} ->
        index(conn, %{"comment_id" => comment.id, "image_id" => comment.image_id})

      {:error, {image, %Ecto.Changeset{}}} ->
        conn
        |> put_flash(:error, "There was an error posting your comment")
        |> redirect(to: ~p"/images/#{image}")

      {:error, :rate_limited} ->
        RateLimitedResponse.call(conn, "You may only create a comment once every 15 seconds.")

      error ->
        error
    end
  end

  def edit(conn, %{"id" => comment_id, "image_id" => image_id}) do
    with {:ok, form} <-
           Comments.edit_comment(conn.assigns.actor, image_id, comment_id) do
      render(conn, "edit.html",
        title: "Editing Comment",
        image: form.data.image,
        comment: form.data,
        changeset: form
      )
    end
  end

  def update(conn, %{"id" => comment_id, "comment" => comment_params, "image_id" => image_id}) do
    case Comments.update_comment(
           conn.assigns.actor,
           image_id,
           comment_id,
           comment_params
         ) do
      {:ok, {image, comment}} ->
        conn
        |> put_flash(:info, "Comment updated successfully.")
        |> redirect(to: ~p"/images/#{image}" <> "#comment_#{comment.id}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html",
          image: changeset.data.image,
          comment: changeset.data,
          changeset: changeset
        )

      {:error, _} = error ->
        error
    end
  end
end
